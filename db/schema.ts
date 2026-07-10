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
