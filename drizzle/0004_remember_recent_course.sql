CREATE TABLE `course_preferences` (
  `user_id` text PRIMARY KEY NOT NULL,
  `last_course_id` text NOT NULL,
  `updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
