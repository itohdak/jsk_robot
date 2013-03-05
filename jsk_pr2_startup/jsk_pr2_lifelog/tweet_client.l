#!/usr/bin/env roseus
(defvar *camera-topic-name* "/openni/rgb/image_rect_color")
(ros::load-ros-manifest "roseus")
(load "package://pr2eus/speak.l")

(ros::roseus "twitter_client")
(ros::advertise "/pr2twit" std_msgs::String 1)

;; next tweet timing ( x(i+1) = x(i) * 2, 5 * 60 = 300 sec)
(while (not (ros::has-param "/active_user/elapsed_time"))
  (unix::sleep 3)
  (ros::ros-info "Wait for /active_user/elapsed_time parameter ..."))

(cond
 ((ros::has-param "/active_user/tweet_second")
  (setq *tweet-second* (ros::get-param "/active_user/tweet_second")))
 (t
  (setq *tweet-second* 300)
  ))

(setq *target-second* (+ (ros::get-param "/active_user/elapsed_time")
                         *tweet-second*))

(setq *waking-tweet-second* 3600.0)
(cond
 ((ros::has-param "/active_user/start_time")
  (let ((st (ros::get-param "/active_user/start_time")))
    (setq *waking-target-second*
          (+ (- (send (ros::time-now) :to-sec) st)
             *waking-tweet-second*))))
 (t
  (setq *waking-target-second* *waking-tweet-second*)))

(setq *src-lines* nil)
(setq *random-state* (coerce (unix::gettimeofday) integer-vector))

(defun twit-cb (msg)
  (let ((twit-str (send msg :data)))
    (speak-jp "さんびょうまえ")
    (unix::sleep 3)
    (unix::system "rm -f /tmp/left*.jpg /tmp/left*.ini")
    (unix::system
     (format nil "(cd /tmp; `rospack find image_view`/bin/image_saver image:=~A __name:=image_saver &)" "/tablet/marked/image_rect_color"))
    (let ((cntr 0))
      (while t
        (if (probe-file "/tmp/left0000.jpg") (return))
        (unix::sleep 2)
        (if (> cntr 20) (return-from twit-cb nil))
        (incf cntr)
        ))

    (unix::system "rosnode kill image_saver")

    (ros::ros-info "tweeting")
    (speak-jp "ついーとしました")
    (ros::publish "/pr2twit"
                  (instance std_msgs::String :init
                            :data (format nil "~A ~A"
                                          twit-str "/tmp/left0000.jpg")))
    ))


(ros::subscribe "/pr2twit_from_tablet" roseus::StringStamped #'twit-cb)

(speak-jp "ついいとちゅうい")
(ros::rate 1)
(do-until-key
  (setq *user-name* (ros::get-param "/active_user/user_name")
        *elapsed-time* (ros::get-param "/active_user/elapsed_time"))
  (ros::ros-info "user -> ~A, time -> ~A (~A) "
                 *user-name* *elapsed-time* *target-second*)
  ;; tweet depend on up time
  (let ((st (ros::get-param "/active_user/start_time")))
    (when st
      (let ((waking-time (- (send (ros::time-now) :to-sec) st)))
        (ros::ros-info "PR2 waking ~A sec (~A)" waking-time *waking-target-second*)
        (when (> waking-time *waking-target-second*)
          (incf *waking-target-second* *waking-tweet-second*)
          ;;(ros::ros-info "waking tweet !!")
          #| ;; tweet fortune
          (let ((fname (format nil "/tmp/tweet_~d.txt" (unix::getpid)))
                str
                lines)
            (unix::system
             (format nil "fortune hitchhiker -n 274 -s > ~A" fname))
            (with-open-file
             (f fname)
             (while (setq str (read-line f nil nil))
               (push str lines)))
            (let* ((ln (apply #'+ (length lines)
                              (mapcar #'(lambda (x) (length x)) lines)))
                   (dt (make-string (1- ln)))
                   (pos 0))
              (dolist (s (nreverse lines))
                (replace dt s :start1 pos)
                (incf pos (length s))
                (if (< pos (- ln 2))
                    (setf (elt dt pos) 10))
                (incf pos))
              ;;(print dt)
              (ros::ros-info "waking tweet !!")
              (ros::publish "/pr2twit"
                            (instance std_msgs::String :init :data dt))
              ))|#
          ;; tweet source of robot-interface
          (unless *src-lines*
            (let* ((dirname (ros::rospack-find "pr2eus"))
                   (fname   (format nil "~A/robot-interface.l" dirname))
                   str)
              (with-open-file (f fname)
                (while (setq str (read-line f nil nil))
                (push str *src-lines*)))
              (setq *src-lines* (nreverse *src-lines*))
              ))

          (let* ((len (length *src-lines*))
                 (start-n (floor (random (float len) *random-state*)))
                 (spos 0) (str-len 0) lines)
            (push (format nil "I am running ~A min." (round (/ waking-time 60.0)))
                  lines)
            (incf str-len (length (car lines)))
            (while (< (+ start-n spos) len)
              (let ((str (elt *src-lines* (+ start-n spos))))
                (incf str-len (length str))
                (if (> str-len 280) (return))
                (push str lines))
              (incf spos))
            (let* ((ln (apply #'+ (length lines)
                              (mapcar #'(lambda (x) (length x)) lines)))
                   (dt (make-string (1- ln)))
                   (pos 0))
              (dolist (s (nreverse lines))
                (replace dt s :start1 pos)
                (incf pos (length s))
                (if (< pos (- ln 2)) (setf (elt dt pos) 10))
                (incf pos))
              ;;(ros::ros-debug "waking tweet !!")
              (ros::ros-info "tweeting")
              (speak-jp "ついーとしました")
              (ros::publish "/pr2twit"
                            (instance std_msgs::String :init :data dt))
              ))
          ))))
  ;; tweet depend on working time
  (when (> *elapsed-time* *target-second*)
    (speak-jp "ごびょうまえ")
    (unix::sleep 5)
    (incf *target-second* *tweet-second* )
    ;; save wide  image and save to /tmp/frame0000.jpg
    (unix::system "rm -f /tmp/left*.jpg")
    (unix::system
     (format nil "(cd /tmp; `rospack find image_view`/bin/image_saver image:=~A _image_transport:=compressed _filename_format:=\"/tmp/frame%04i.jpg\" _sec_per_frame:=1 __name:=image_saver &)"
             *camera-topic-name*))
    (let ((cntr 0))
      (while t
        (if (probe-file "/tmp/left0000.jpg") (return))
        (unix::sleep 2)
        (if (> cntr 20) (return))
        (incf cntr)
        ))
    (unix::system "rosnode kill image_saver")
    ;; tweet
    (ros::ros-info "tweet ~A ~A" *user-name* *elapsed-time*)
    (let ((mainstr (format nil "~A have used PR2 for ~d minutes"
                           ;; why delete *user-name* after space ?
                           ;;(subseq *user-name* 0
                           ;;(or (position #\space *user-name*)
                           ;;(length *user-name*)))
                           *user-name*
                           (round (/ *elapsed-time* 60))))
          (filenamestr "/tmp/left0000.jpg")
          presubstr postsubstr)
      (cond
       ((< *elapsed-time* 300) ;; 5 min
        (setq presubstr "Congratulations! "
              postsubstr ", Let's get started!"))
       ((< *elapsed-time* 900) ;; 15 min
        (setq presubstr "Gooood! "
              postsubstr ", Go ahead!"))
       ((< *elapsed-time* 1800) ;; 30 min
        (setq presubstr "So Nice! "
              postsubstr ", Go ahead!"))
       ((< *elapsed-time* 2700) ;; 45 min
        (setq presubstr "Fantastic! "
              postsubstr ", Keep going!"))
       ((< *elapsed-time* 3600) ;; 60 min
        (setq presubstr "Amazing! "
              postsubstr ", I'm not tired!"))
       (t
        (setq presubstr "Awesome! "
              postsubstr ", Got some rest?")))

      (ros::ros-info "tweeting")
      (speak-jp "ついーとしました")
      (ros::publish "/pr2twit"
                    (instance std_msgs::String :init
                              :data (format nil "~A~A~A ~A"
                                            presubstr
                                            mainstr
                                            postsubstr
                                            filenamestr)))
      ))
  (ros::spin-once)
  (ros::sleep)
  )