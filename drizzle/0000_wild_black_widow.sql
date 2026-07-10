CREATE TABLE `word_progress` (
	`user_id` text NOT NULL,
	`word` text NOT NULL,
	`study_count` integer DEFAULT 0 NOT NULL,
	`updated_at` text NOT NULL,
	PRIMARY KEY(`user_id`, `word`)
);
