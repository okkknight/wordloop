CREATE TABLE `course_mode_progress` (
	`user_id` text NOT NULL,
	`study_mode` text NOT NULL,
	`course_id` text NOT NULL,
	`item_id` text NOT NULL,
	`study_count` integer DEFAULT 0 NOT NULL,
	`updated_at` text NOT NULL,
	PRIMARY KEY(`user_id`, `study_mode`, `course_id`, `item_id`)
);
--> statement-breakpoint
CREATE TABLE `word_mode_progress` (
	`user_id` text NOT NULL,
	`study_mode` text NOT NULL,
	`word` text NOT NULL,
	`study_count` integer DEFAULT 0 NOT NULL,
	`updated_at` text NOT NULL,
	PRIMARY KEY(`user_id`, `study_mode`, `word`)
);
