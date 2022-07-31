CREATE TABLE "bad_posts" (
    "id" SERIAL PRIMARY KEY,
    "topic" VARCHAR(50),
    "username" VARCHAR(50),
    "title" VARCHAR(150),
    url VARCHAR(4000) DEFAULT NULL,
    "text_content" TEXT DEFAULT NULL,
    "upvotes" TEXT,
    "downvotes" TEXT
);

CREATE TABLE "bad_comments" (
    "id" SERIAL PRIMARY KEY,
    "username" VARCHAR(50),
    "post_id" BIGINT,
    "text_content" TEXT
);

----------------------------------------------
-- PART II: CREATE THE DDL FOR YOUR NEW SCHEMA
----------------------------------------------
-- Guideline #1a
CREATE TABLE "users" (
    "id" SERIAL PRIMARY KEY,
    -- Each username has to be unique
    -- Usernames can be composed of at most 25 characters
    "username" VARCHAR(25) UNIQUE NOT NULL,
    "login" TIMESTAMP WITH TIME ZONE,
    -- Usernames can't be empty
    CONSTRAINT "username_not_empty" CHECK(LENGTH(TRIM("username")) > 1)
);

-- Guideline #1b
CREATE TABLE "topics" (
    "id" SERIAL PRIMARY KEY,
    -- Topic name has to be unique
    -- Topic name is at most 30 characters
    "topic" VARCHAR(30) UNIQUE NOT NULL,
    -- Topics can have optional description
    "description" VARCHAR(500),
    -- Topic name cannot be empty
    CONSTRAINT "topic_name_length" CHECK (LENGTH(TRIM("topic")) > 1)
);

-- Guideline #1c
-- Allow registered users to creat new posts on existing topics
CREATE TABLE "posts" (
    "id" SERIAL PRIMARY KEY,
    -- Posts have a required title of at most 100 characters
    "title" VARCHAR(100) NOT NULL,
    "post_url" VARCHAR(4000),
    "post_text" TEXT,
    -- If a user is deleted, all post will remain under a null user
    "user_id" INT,
    -- If a topic is deleted, then all post should be deleted in that
    topic
    "topic_id" INT NOT NULL,
    "date_created" TIMESTAMP WITH TIME ZONE,
    CONSTRAINT "fk_user_id" FOREIGN KEY ("user_id") REFERENCES
    "users"("id") ON DELETE SET NULL,
    CONSTRAINT "fk_topic_id" FOREIGN KEY ("topic_id") REFERENCES
    "topics"("id") ON DELETE CASCADE,
    -- The title cannot be empty
    CONSTRAINT "title_not_empty" CHECK(LENGTH(TRIM("title")) > 0),
    -- Posts should contain either a url or text but not both
    CONSTRAINT "post_or_url" CHECK(("post_url" IS NOT NULL AND
    "post_text" IS NULL)
    OR ("post_url" IS NULL AND "post_text"
    IS NOT NULL))
);
CREATE INDEX "topic_by_date" ON "posts" ("topic_id", "date_created");
CREATE INDEX "user_post_by_date" ON "posts" ("user_id", "date_created");

-- Guideline #1d (Allow registered users to comment on existing post)
CREATE TABLE "comments"(
    "id" SERIAL PRIMARY KEY,
    "content" TEXT NOT NULL,
    "post_id" INTEGER NOT NULL,
    "user_id" INTEGER,
    "comment_id" INTEGER,
    "date_created" TIMESTAMP WITH TIME ZONE,
    CONSTRAINT "fk_user_id" FOREIGN KEY ("user_id") REFERENCES
    "users"("id") ON DELETE SET NULL,
    CONSTRAINT "fk_post_id" FOREIGN KEY ("post_id") REFERENCES
    "posts"("id") ON DELETE CASCADE,
    CONSTRAINT "comment_not_empty" CHECK (LENGTH(TRIM("content")) > 1)
    );
    CREATE INDEX "parent_comment_relation" ON "comments" ("comment_id",
    "id");
    CREATE INDEX "user_comment" ON "comments" ("user_id");
    -- Guideline #1e (Make sure that a given user can only vote once on a
    given post)
    CREATE TABLE "votes"(
    "id" SERIAL PRIMARY KEY,
    "post_id" INTEGER NOT NULL REFERENCES "posts"("id"),
    "user_id" INTEGER NOT NULL REFERENCES "users"("id") ON DELETE SET
    NULL,
    "vote" BOOL NOT NULL,
    CONSTRAINT "unique_vote" UNIQUE ("user_id", "post_id"),
    CONSTRAINT "vote_check" CHECK ("vote" = FALSE OR "vote" = TRUE)
);

--------------------------------------
-- PART III: Migrate the provided data
--------------------------------------
-- Migrate to Users
INSERT INTO "users"("username")
SELECT DISTINCT "username"
FROM "bad_posts"
UNION SELECT DISTINCT "username"
FROM "bad_comments"
UNION SELECT DISTINCT REGEXP_SPLIT_TO_TABLE("upvotes", ',') "username"
FROM "bad_posts"
UNION SELECT DISTINCT REGEXP_SPLIT_TO_TABLE("downvotes", ',')
"username"
FROM "bad_posts";

-- Migrate to topics
INSERT INTO "topics" ("topic")
SELECT DISTINCT "topic" FROM "bad_posts";

-- Migrate to posts
INSERT INTO "posts" ("title", "post_url", "post_text", "user_id",
"topic_id")
SELECT  LEFT(b.title, 100), 
        b.url, 
        b.text_content, 
        u.id, 
        t.id
FROM "bad_posts" b
JOIN "users" u ON b.username = u.username
JOIN "topics" t ON t.topic = b.topic;

-- Migrate to comments
INSERT INTO "comments" ("content","post_id","user_id", "comment_id")
SELECT  bc."text_content", 
        p."id", 
        u."id", 
        bc."id"
FROM "bad_comments" bc
JOIN "posts" p
ON bc."post_id" = p."id"
JOIN "users" u
ON u."username" = bc."username";

-- Migrate to votes
INSERT INTO "votes" ("post_id","user_id","vote")
WITH down_votes AS(
SELECT id, REGEXP_SPLIT_TO_TABLE("downvotes", ',') AS "down_vote"
FROM "bad_posts"
),
up_votes AS(
SELECT id, REGEXP_SPLIT_TO_TABLE("upvotes", ',') AS "up_vote"
FROM "bad_posts"
)
SELECT p.id AS "post_id", u.id AS "user_id", FALSE AS vote
FROM "down_votes" d
JOIN "users" u
ON d.down_vote = u.username
JOIN "posts" p
ON p.id = d.id
UNION ALL
SELECT p.id AS "post_id", u.id AS "user_id", TRUE AS vote
FROM "up_votes" uv
JOIN "users" u
ON uv.up_vote = u.username
JOIN "posts" p
ON p.id = uv.id;