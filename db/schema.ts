import { integer, primaryKey, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const wordProgress = sqliteTable(
  "word_progress",
  {
    userId: text("user_id").notNull(),
    word: text("word").notNull(),
    studyCount: integer("study_count").notNull().default(0),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [primaryKey({ columns: [table.userId, table.word] })],
);

export const wordModeProgress = sqliteTable(
  "word_mode_progress",
  {
    userId: text("user_id").notNull(),
    studyMode: text("study_mode", { enum: ["listen", "repeat"] }).notNull(),
    word: text("word").notNull(),
    studyCount: integer("study_count").notNull().default(0),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [primaryKey({ columns: [table.userId, table.studyMode, table.word] })],
);

export const courseModeProgress = sqliteTable(
  "course_mode_progress",
  {
    userId: text("user_id").notNull(),
    studyMode: text("study_mode", { enum: ["listen", "repeat"] }).notNull(),
    courseId: text("course_id").notNull(),
    itemId: text("item_id").notNull(),
    studyCount: integer("study_count").notNull().default(0),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [primaryKey({ columns: [table.userId, table.studyMode, table.courseId, table.itemId] })],
);

export const progressEvents = sqliteTable("progress_events", {
  eventId: text("event_id").primaryKey(),
  userId: text("user_id").notNull(),
  studyMode: text("study_mode", { enum: ["listen", "repeat"] }).notNull(),
  courseId: text("course_id"),
  itemId: text("item_id"),
  word: text("word"),
  createdAt: text("created_at").notNull(),
});
