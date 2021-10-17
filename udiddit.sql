DROP TABLE IF EXISTS user_account;

CREATE TABLE user_account(
    id SERIAL,
    username VARCHAR(25),
    last_login TIMESTAMP WITH TIME ZONE,
    UNIQUE(username),
    CONSTRAINT username_nonnull_nonempty
        CHECK (NULLIF(TRIM(username), '') IS NOT NULL),
    CONSTRAINT user_account_pkey 
        PRIMARY KEY(id)
);

DROP TABLE IF EXISTS topic;

CREATE TABLE topic(
    id SERIAL,
    user_id INTEGER,
    topic_name VARCHAR(30),
    topic_description VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(topic_name),
    CONSTRAINT topic_title_nonnull_nonempty
        CHECK (NULLIF(TRIM(topic_name), '') IS NOT NULL),
    CONSTRAINT topic_pkey 
        PRIMARY KEY(id),
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_account(id)
);

DROP TABLE IF EXISTS post;

CREATE TABLE post(
    id INTEGER,
    topic_id INTEGER NOT NULL,
    user_id INTEGER,
    title VARCHAR(100),
    url TEXT,
    text_content TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT post_title_nonnull_nonempty
        CHECK (NULLIF(TRIM(title), '') IS NOT NULL),
    CONSTRAINT url_text_context_one_nonempty 
        CHECK (
                (NULLIF(TRIM(url), '') IS NULL 
                    OR NULLIF(TRIM(text_content), '') IS NULL) 
                AND NOT (NULLIF(TRIM(url), '') IS NULL 
                    AND NULLIF(TRIM(text_content), '') IS NULL)
        ),
    CONSTRAINT post_pkey 
        PRIMARY KEY(id),
    CONSTRAINT fk_topic
        FOREIGN KEY(topic_id)
            REFERENCES topic(id)
            ON DELETE CASCADE,
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_account(id)
            ON DELETE SET NULL
);

DROP TABLE IF EXISTS vote;

CREATE TABLE vote(
    id SERIAL,
    post_id INTEGER NOT NULL,
    user_id INTEGER,
    vote_cast SMALLINT NOT NULL,
    CONSTRAINT one_vote_one_user 
        UNIQUE(post_id, user_id),
    CONSTRAINT vote_choice
        CHECK (vote_cast in (1, -1)),
    CONSTRAINT vote_pkey PRIMARY KEY(id),   
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_account(id)
            ON DELETE SET NULL,
    CONSTRAINT fk_post
        FOREIGN KEY(post_id)
            REFERENCES post(id)
            ON DELETE CASCADE
);

DROP TABLE IF EXISTS comment;

CREATE TABLE comment(
    id INTEGER,
    post_id INTEGER NOT NULL,
    user_id INTEGER,
    parent_id INTEGER, -- should be NOT NULL but we don't have data
    text_content TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT comment_text_content_non_empty
        CHECK (NULLIF(TRIM(text_content), '') IS NOT NULL),
    CONSTRAINT comment_pkey 
        PRIMARY KEY(id),
    CONSTRAINT fk_post
        FOREIGN KEY(post_id)
            REFERENCES post(id)
            ON DELETE CASCADE,
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_account(id)
            ON DELETE SET NULL,
    CONSTRAINT fk_comment
        FOREIGN KEY(parent_id)
            REFERENCES comment(id)
            ON DELETE CASCADE
);

-- create a votes view - to be dropped at the end
CREATE VIEW vote_view 
AS 
SELECT id post_id, 
    regexp_split_to_table(upvotes, ',') username,
    1 vote_cast
FROM bad_posts
UNION
SELECT id post_id,
    regexp_split_to_table(downvotes, ',') username,
    -1 vote_cast
FROM bad_posts;

-- populate user_account table
INSERT INTO user_account(username)
(SELECT DISTINCT(username::VARCHAR(25)) 
FROM bad_posts
UNION
SELECT DISTINCT(username::VARCHAR(25))
FROM bad_comments
UNION
SELECT DISTINCT(username::VARCHAR(25))
FROM vote_view
);

-- populate topic table
INSERT INTO topic(topic_name)
SELECT bp.topic::VARCHAR(30)
FROM bad_posts bp
JOIN user_account ua
ON bp.username = ua.username
GROUP BY 1;

-- populate post table
INSERT INTO post(id, topic_id, user_id, title, url, text_content)
SELECT bp.id id, 
    t.id topic_id, 
    ua.id user_id,
    bp.title::VARCHAR(100) title, 
    bp.url url, 
    bp.text_content text_content
FROM bad_posts bp
JOIN user_account ua
ON bp.username = ua.username
JOIN topic t
ON bp.topic = t.topic_name;

-- populate table vote
INSERT INTO vote(post_id, user_id, vote_cast)
SELECT vw.post_id post_id, 
    ua.id user_id, 
    vw.vote_cast vote
FROM vote_view vw
JOIN user_account ua
ON vw.username = ua.username;

-- populate table comment
INSERT INTO comment(id, post_id, user_id, text_content)
SELECT bc.id id,
    bc.post_id post_id, 
    ua.id user_id, 
    bc.text_content text_content
FROM user_account ua
JOIN bad_comments bc
ON ua.username = bc.username;

-- indices
-- table: user
CREATE INDEX index_last_login_user ON user_account(last_login);

-- table: topic
CREATE INDEX index_fk_user_topic ON topic(user_id);
CREATE INDEX index_created_at_topic ON topic(created_at);

-- table: post
CREATE INDEX index_fk_topic_post ON post(topic_id);
CREATE INDEX index_fk_user_post ON post(user_id);
CREATE INDEX index_created_at_post ON post(created_at);
CREATE INDEX index_url_post ON post(url);

-- table: vote
CREATE INDEX index_fk_post_vote ON vote(post_id);
CREATE INDEX index_fk_user_vote ON vote(user_id);
CREATE INDEX index_post_vote ON vote(post_id, vote_cast);

-- table: comment
CREATE INDEX index_fk_post_comment ON comment(post_id);
CREATE INDEX index_fk_user_comment ON comment(user_id);
CREATE INDEX index_fk_parent_comment ON comment(parent_id);
CREATE INDEX index_created_at_comment ON comment(created_at);

-- drop view
DROP VIEW vote_view;
