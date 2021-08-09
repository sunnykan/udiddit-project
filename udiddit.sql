DROP TABLE IF EXISTS user_account;

CREATE TABLE user_account(
    id SERIAL,
    username VARCHAR(25) NOT NULL,
    UNIQUE(username),
    CONSTRAINT user_account_pkey PRIMARY KEY(id)

);

-- The user name cannot be empty.
ALTER TABLE user_account
ADD CHECK(LENGTH(TRIM(username)) > 0);

DROP TABLE IF EXISTS topic;

CREATE TABLE topic(
    id SERIAL,
    user_id INTEGER,
    name VARCHAR(30) NOT NULL,
    description VARCHAR(500),
    UNIQUE(name),
    CONSTRAINT topic_pkey PRIMARY KEY(id),
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_account(id)
);

-- The topic's name cannot be empty.
ALTER TABLE topic
ADD CHECK(LENGTH(TRIM(name)) > 0);

DROP TABLE IF EXISTS post;

CREATE TABLE post(
    id INTEGER,
    topic_id INTEGER,
    user_id INTEGER,
    title VARCHAR(100) NOT NULL,
    url TEXT,
    text_content TEXT,
    CONSTRAINT fk_topic
        FOREIGN KEY(topic_id)
            REFERENCES topic(id)
            ON DELETE CASCADE,
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_account(id)
            ON DELETE SET NULL
);

-- The title of a post cannot be empty.
ALTER TABLE post
ADD CHECK(LENGTH(TRIM(title)) > 0);

-- Posts should contain either a URL or a text content, but not both.
ALTER TABLE post
ADD CONSTRAINT url_xor_content
CHECK (
        num_nonnulls(url, text_content) = 1
);

-- create a votes view - to be dropped at the end
CREATE VIEW vote_view 
AS 
SELECT id as post_id, 
    regexp_split_to_table(upvotes, ',') as username,
    1 as vote
FROM bad_posts
UNION
SELECT id as post_id,
    regexp_split_to_table(downvotes, ',') as username,
    -1 as vote
FROM bad_posts;

-- populate user_account table
INSERT INTO user_account(username)
(SELECT DISTINCT(username) 
FROM bad_posts
UNION
SELECT DISTINCT(username)
FROM bad_comments
);

INSERT INTO user_account(username)
(SELECT username
FROM vote_view
EXCEPT
SELECT username
FROM user_account
);

-- populate topic table
INSERT INTO topic(name)
SELECT bp.topic
FROM bad_posts bp
JOIN user_account ua
ON bp.username = ua.username
GROUP BY 1;

-- populate post table
INSERT INTO post(id, topic_id, user_id, title, url, text_content)
SELECT bp.id id, 
    t.id topic_id, 
    ua.id user_id,
    bp.title::varchar(100) title, 
    bp.url url, 
    bp.text_content text_content
FROM bad_posts bp
JOIN user_account ua
ON bp.username = ua.username
JOIN topic t
ON bp.topic = t.name;

ALTER TABLE post ADD CONSTRAINT post_pkey PRIMARY KEY(id);

DROP TABLE IF EXISTS vote;

CREATE TABLE vote(
    id SERIAL,
    post_id INTEGER,
    user_id INTEGER,
    vote SMALLINT,
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

-- Populate table vote
INSERT INTO vote(post_id, user_id, vote)
SELECT vw.post_id post_id, ua.id user_id, vw.vote vote
FROM vote_view vw
JOIN user_account ua
ON vw.username = ua.username;

DROP TABLE IF EXISTS comment;

CREATE TABLE comment(
    id SERIAL,
    post_id INTEGER,
    user_id INTEGER,
    text_content TEXT NOT NULL,
    parent_id INTEGER,
    CONSTRAINT content_pkey PRIMARY KEY(id),
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

ALTER TABLE comment
ADD CHECK(LENGTH(TRIM(text_content)) > 0);

-- Populate table comment
INSERT INTO comment(post_id, user_id, text_content)
SELECT bc.post_id post_id, ua.id user_id, bc.text_content text_content
FROM user_account ua
JOIN bad_comments bc
ON ua.username = bc.username;


DROP VIEW vote_view;


