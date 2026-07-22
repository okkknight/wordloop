CREATE TABLE `course_resume_positions` (
  `user_id` text NOT NULL,
  `study_mode` text NOT NULL,
  `course_id` text NOT NULL,
  `resume_item_id` text NOT NULL,
  `updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  PRIMARY KEY(`user_id`, `study_mode`, `course_id`)
);
