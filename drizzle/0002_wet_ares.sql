CREATE TABLE `progress_events` (
	`event_id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`study_mode` text NOT NULL,
	`course_id` text,
	`item_id` text,
	`word` text,
	`created_at` text NOT NULL
);
