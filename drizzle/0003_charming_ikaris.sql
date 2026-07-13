CREATE TABLE `course_completion_counts` (
	`user_id` text NOT NULL,
	`course_id` text NOT NULL,
	`completion_count` integer DEFAULT 0 NOT NULL,
	`updated_at` text NOT NULL,
	PRIMARY KEY(`user_id`, `course_id`)
);
--> statement-breakpoint
CREATE TABLE `course_completion_events` (
	`event_id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`course_id` text NOT NULL,
	`created_at` text NOT NULL
);
