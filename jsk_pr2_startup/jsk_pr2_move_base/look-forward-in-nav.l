#!/usr/bin/env roseus
(ros::roseus-add-msgs "nav_msgs")
(ros::roseus-add-msgs "sound_play")
(load "package://pr2eus/pr2-interface.l")

(setq *look-enable* t)
(setq *speak-timestamp* (ros::time 0))

(defun init ()
  (pr2)
  (ros::roseus "look-formward")
  (ros::subscribe "/move_base_node/DWAPlannerROS/global_plan"
		  nav_msgs::Path #'global-path-cb 1)
  (ros::advertise "robotsound" sound_play::SoundRequest 5)
  (setq *ri* (instance pr2-interface :init))
  (defvar *tfl* (instance ros::transform-listener :init))
  )

(defun speak-jp (jp-str)
  (ros::publish "robotsound"
		(instance sound_play::SoundRequest :init
			  :sound sound_play::SoundRequest::*say*
			  :command sound_play::SoundRequest::*play_once*
			  :arg jp-str)))

(defun global-path-cb (msg)
  (let ((co (ros::tf-pose->coords (send (car (last (send msg :poses))) :pose)))
	(tra (send *tfl* :lookup-transform "base_link" "odom_combined" (ros::time 0)))
	(av (send *pr2* :angle-vector)))
    ;; need convert ?
    (when (not tra)
      (ros::ros-error "not transform")
      (return-from global-path-cb nil))
    (send tra :transform co)
    (ros::ros-info "msg received ~A~%" msg (norm (send tra :worldpos)))

    (when *look-enable*
      (if (< 500 (norm (send tra :worldpos)))
	  (send *pr2* :head :look-at (v+ #f(0 0 1300) (send tra :worldpos)))
	(send *pr2* :head :look-at #f(0 0 1300)))
      ;;(send *ri* :angle-vector (send *pr2* :angle-vector) 500)
      (if (> (abs (send *pr2* :head :neck-p :joint-angle)) 30)
	  (ros::ros-error "error head ik ~A ~A" av (v+ #f(0 0 1300) (send tra :worldpos)))
	(send *ri* :head-angle-vector (send *pr2* :angle-vector) 500)))

    (when (and (< 3.0 (send (ros::time- (ros::time-now) *speak-timestamp*) :to-sec))
	       (< 1000 (norm (send tra :worldpos))))
      (setq ang (atan (elt (send tra :worldpos) 1)
		      (elt (send tra :worldpos) 0)))
      (when (< (* 0.25 pi) ang (* 0.50 pi))
	(speak-jp "ひだりにまがります")
	(setq *speak-timestamp* (ros::time-now)))
      (when (> (* -0.25 pi) ang (* -0.50 pi))
	(speak-jp "みぎにまがります")
	(setq *speak-timestamp* (ros::time-now)))
      (ros::ros-info "angle = ~A" ang)
      )
    (ros::ros-info "~A plan trajectory end point ~A, head angle ~A" msg (send tra :worldpos) (send *pr2* :head :angle-vector))
    ))

(init)
(ros::spin-once)
(send *pr2* :angle-vector (send *ri* :state :potentio-vector))
;;
(ros::rate 5)
(while (ros::ok)
  (ros::sleep)
  (ros::spin-once))