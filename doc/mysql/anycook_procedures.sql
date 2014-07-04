SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

CREATE SCHEMA IF NOT EXISTS `anycook_db` DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ;
USE `anycook_db` ;
USE `anycook_db` ;

-- -----------------------------------------------------
-- procedure search_by_ingredient
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`search_by_ingredient`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`search_by_ingredient` (IN ingredient_in VARCHAR(45))
BEGIN

DECLARE rowcount INT;
DECLARE current_ingredient VARCHAR(45);

CREATE TEMPORARY TABLE tmp_ingredients (ingredient VARCHAR(45) PRIMARY KEY NOT NULL) engine=memory;
CREATE TEMPORARY TABLE ingredient_stack (ingredient VARCHAR(45) PRIMARY KEY NOT NULL) engine=memory SELECT ingredient_in AS ingredient;

REPEAT
	SELECT ingredient INTO current_ingredient FROM ingredient_stack LIMIT 1;
	INSERT INTO tmp_ingredients VALUES (current_ingredient);
	DELETE FROM ingredient_stack WHERE ingredient = current_ingredient;
	INSERT INTO ingredient_stack (ingredient) SELECT name FROM zutaten WHERE parent_zutaten_name = current_ingredient;
	SET rowcount = (SELECT COUNT(*) FROM ingredient_stack);
UNTIL (rowcount = 0) END REPEAT;

DROP TEMPORARY TABLE ingredient_stack;

SELECT found_recipes.name, COUNT(found_recipes.users) AS schmecktcount FROM (
	SELECT gerichte.name AS name, schmeckt.users_id AS users from gerichte
		INNER JOIN versions_has_zutaten ON gerichte.name = versions_gerichte_name AND gerichte.active_id = versions_id
		LEFT JOIN schmeckt ON gerichte.name = schmeckt.gerichte_name
		WHERE zutaten_name IN	(SELECT * FROM tmp_ingredients) 
		GROUP BY gerichte.name, schmeckt.users_id) AS found_recipes 
	GROUP BY found_recipes.name
	ORDER BY schmecktcount DESC;

DROP TEMPORARY TABLE tmp_ingredients;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure new_user
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`new_user`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`new_user` (IN uname VARCHAR(45), IN upass VARCHAR(45), IN umail VARCHAR(45), IN uniqueid VARCHAR(20), 
	IN uimage VARCHAR(45), OUT uid INT)
BEGIN
	DECLARE usercount BOOL;	
	DECLARE no_more_types BOOL DEFAULT 0;
	DECLARE mailnot_type VARCHAR(40);
	DECLARE mailnot_cur CURSOR FOR SELECT type FROM mailnotifications;
	DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET no_more_types = 1;
	

	SET uid = 0;
	SELECT COUNT(*) INTO usercount FROM users WHERE nickname = uname OR email = umail LIMIT 1;
	IF usercount = 0 THEN
		INSERT INTO users(nickname, email, password, createdate, image) VALUES (uname, umail, PASSWORD(upass), CURDATE(), uimage);
		SELECT id INTO uid FROM users WHERE email = umail;

		OPEN mailnot_cur;
		FETCH mailnot_cur INTO mailnot_type;
		REPEAT
			INSERT INTO users_has_mailnotifications(users_id, mailnotifications_type) VALUES (uid, mailnot_type);
			FETCH mailnot_cur INTO mailnot_type;
		UNTIL no_more_types = 1
		END REPEAT;
		CLOSE mailnot_cur;

		IF uniqueid IS NOT NULL THEN
			INSERT INTO activationids (users_id, activationid) VALUES (uid, uniqueid);
		ELSE
			UPDATE users SET userlevels_id = 0;
		END IF;

	END IF;		
	
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure recipe_ingredients
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`recipe_ingredients`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`recipe_ingredients` (IN recipe_name VARCHAR(45))
BEGIN
	SELECT zutaten_name, singular, menge FROM gerichte
		INNER JOIN versions_has_zutaten ON gerichte.active_id = versions_id AND gerichte.name = versions_gerichte_name 
		INNER JOIN zutaten ON zutaten_name = zutaten.name 
		WHERE versions_gerichte_name = recipe_name;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure recipes_from_schmeckttags
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`recipes_from_schmeckttags`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`recipes_from_schmeckttags` (IN userid INT)
BEGIN
	SELECT gerichte_name, tags_name FROM gerichte_has_tags
	WHERE tags_name IN 
		(SELECT tags_name from schmeckt 
			INNER JOIN gerichte_has_tags USING (gerichte_name)
			WHERE active = 1 AND schmeckt.users_id = userid GROUP BY tags_name)
	AND gerichte_name NOT IN 
		(SELECT gerichte_name FROM versions WHERE users_id = userid GROUP BY gerichte_name)
	AND gerichte_name NOT IN
		(SELECT gerichte_name FROM schmeckt WHERE users_id = userid);	
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure get_recipe
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`get_recipe`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`get_recipe` (IN recipe_name VARCHAR(45), IN login_id INT)
BEGIN

SELECT versions.id AS id, gerichte.name AS name, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, personen, kategorien_name, active_id, users_id, nickname, users.image, viewed,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange,
	(SELECT COUNT(users_id) FROM schmeckt WHERE schmeckt.gerichte_name = recipe_name AND schmeckt.users_id = login_id) AS tastes
FROM gerichte
INNER JOIN versions ON IF(active_id > 0, gerichte.name = gerichte_name AND active_id = versions.id, gerichte.name = gerichte_name) 
INNER JOIN users ON users_id = users.id
INNER JOIN kategorien ON kategorien_name = kategorien.name 
WHERE gerichte.name = recipe_name;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure recipe_image
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`recipe_image`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`recipe_image` (IN recipe_name VARCHAR(45))
BEGIN
	SELECT imagename, kategorien.image FROM gerichte 
		INNER JOIN versions ON gerichte_name = name AND id = active_id
		INNER JOIN kategorien ON versions.kategorien_name = kategorien.name
		WHERE gerichte.name = recipe_name;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure get_discussion
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`get_discussion`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`get_discussion` (IN recipe_name VARCHAR(45), IN maxid INT, IN userid INT)
BEGIN
	SELECT parent_id, discussions.id, nickname, users.id, users.image, versions_id, discussions.text, discussions.eingefuegt, 
		syntax, COUNT(discussions_like.users_id) AS votes, IF(discussions_like.users_id = userid, 1, 0) AS liked,
		gerichte.active_id FROM discussions
		LEFT JOIN users ON discussions.users_id = users.id 
		LEFT JOIN gerichte ON gerichte_name = gerichte.name 
		LEFT JOIN discussions_like ON gerichte_name = discussions_gerichte_name AND discussions.id = discussions_id 
		LEFT JOIN discussions_events ON discussions_events_name = discussions_events.name 
		WHERE gerichte_name = recipe_name AND discussions.id > maxid GROUP BY discussions.id ORDER BY discussions.id;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure backend_get_version
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`backend_get_version`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`backend_get_version` (IN recipeName VARCHAR(45))
BEGIN
	SELECT id, eingefuegt, steps.count, ingredients.count, viewed_by_admin, users_id, imagename, beschreibung
		FROM versions
		LEFT JOIN (SELECT versions_id, COUNT(idschritte) AS count FROM schritte 
			WHERE versions_gerichte_name = recipeName GROUP BY versions_id) AS steps ON id = steps.versions_id
		LEFT JOIN (SELECT versions_id, COUNT(zutaten_name) AS count FROM versions_has_zutaten 
			WHERE versions_gerichte_name = recipeName GROUP BY versions_id) AS ingredients ON id = ingredients.versions_id
		WHERE gerichte_name = recipeName
		GROUP BY id ORDER BY id;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure backend_get_all_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`backend_get_all_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`backend_get_all_recipes` ()
BEGIN
	SELECT name, gerichte.eingefuegt, active_id, viewed, COUNT(schmeckt.users_id) AS schmeckt, 
		MIN(viewed_by_admin) AS adminviewed, 
		(SELECT COUNT(id) FROM versions WHERE gerichte_name = name) AS num_versions 
		FROM gerichte
		LEFT JOIN versions ON versions.gerichte_name = name
		LEFT JOIN schmeckt ON schmeckt.gerichte_name = name
		GROUP BY name, versions.id ORDER BY eingefuegt DESC;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure backend_get_recipe
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`backend_get_recipe`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`backend_get_recipe` (IN recipeName VARCHAR(45))
BEGIN
	SELECT name, gerichte.eingefuegt, active_id, viewed, COUNT(schmeckt.users_id) AS schmeckt, 
		MIN(viewed_by_admin) AS adminviewed, 
		(SELECT COUNT(id) FROM versions WHERE gerichte_name = recipeName) AS num_versions 
		FROM gerichte
		LEFT JOIN versions ON versions.gerichte_name = name
		LEFT JOIN schmeckt ON schmeckt.gerichte_name = name
		WHERE name = recipeName
		GROUP BY name, versions.id ORDER BY eingefuegt DESC;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure backend_update_recipe
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`backend_update_recipe`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`backend_update_recipe` (IN recipeName VARCHAR(45), IN new_activeId INT)
BEGIN
	UPDATE gerichte SET active_id = new_activeId WHERE name = recipeName;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure backend_delete_recipe
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`backend_delete_recipe`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`backend_delete_recipe` (IN recipeName VARCHAR(45))
BEGIN
	DECLARE check_exist BOOL;

	SELECT COUNT(*) INTO check_exist FROM gerichte WHERE recipeName = name;

	IF check_exist THEN
		DELETE FROM discussions_like WHERE discussions_gerichte_name = recipeName;
		DELETE FROM tagesrezepte WHERE gerichte_name = recipeName;
		DELETE FROM discussions WHERE gerichte_name = recipeName;
		DELETE FROM gerichte_has_tags WHERE gerichte_name = recipeName;
		DELETE FROM life WHERE gerichte_name = recipeName;
		DELETE FROM schmeckt WHERE gerichte_name = recipeName;
		DELETE FROM schritte_has_zutaten WHERE schritte_versions_gerichte_name = recipeName;
 		DELETE FROM schritte WHERE versions_gerichte_name = recipeName;
		DELETE FROM versions_has_zutaten WHERE versions_gerichte_name = recipeName;
		DELETE FROM versions WHERE gerichte_name = recipeName;
		DELETE FROM gerichte WHERE name = recipeName;

	END IF;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure backend_get_users
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`backend_get_users`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`backend_get_users` ()
BEGIN
	SELECT id, nickname, email, lastlogin, createdate, userlevels_id, facebook_id, place, 
		follower.followerCount AS numFollowers, following.followingCount AS numFollowing, recipes.recipeCount AS recipeCount FROM users
		LEFT JOIN (SELECT COUNT(users_id) AS followerCount, following FROM followers GROUP BY following) AS follower ON id = follower.following
		LEFT JOIN (SELECT COUNT(following) AS followingCount, users_id FROM followers GROUP BY users_id) AS following ON id = following.users_id
		LEFT JOIN (SELECT COUNT(name) AS recipeCount, users_id FROM versions INNER JOIN gerichte ON name = gerichte_name GROUP BY users_id) AS recipes 
			ON recipes.users_id = id;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure backend_get_user
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`backend_get_user`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`backend_get_user` (IN userId INT)
BEGIN
	SELECT id, nickname, email, lastlogin, createdate, userlevels_id, facebook_id, place, 
		follower.followerCount AS numFollowers, following.followingCount AS numFollowing, recipes.recipeCount AS recipeCount FROM users
		LEFT JOIN (SELECT COUNT(users_id) AS followerCount, following FROM followers GROUP BY following) AS follower ON id = follower.following
		LEFT JOIN (SELECT COUNT(following) AS followingCount, users_id FROM followers GROUP BY users_id) AS following ON id = following.users_id
		LEFT JOIN (SELECT COUNT(name) AS recipeCount, users_id FROM versions INNER JOIN gerichte ON name = gerichte_name GROUP BY users_id) AS recipes 
			ON recipes.users_id = id
		WHERE id = userId;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure tasty_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`tasty_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `tasty_recipes` (IN length INT, IN login_id INT)
BEGIN

SELECT versions.id AS id, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, gerichte.name AS name, personen, kategorien_name, active_id, users_id, nickname, users.image, COUNT(users_id) AS counter, viewed,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange,
	(SELECT COUNT(users_id) FROM schmeckt WHERE schmeckt.gerichte_name = gerichte.name AND schmeckt.users_id = login_id) AS tastes 
	FROM gerichte
	INNER JOIN versions ON gerichte.name = gerichte_name AND active_id = versions.id 
	INNER JOIN users ON users_id = users.id
	INNER JOIN kategorien ON kategorien_name = kategorien.name 
	GROUP BY gerichte.name ORDER BY counter DESC LIMIT length;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure popular_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`popular_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `popular_recipes` (IN length INT, IN login_id INT)
BEGIN

SELECT versions.id AS id, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, gerichte.name, personen, kategorien_name, active_id, users_id, nickname, users.image, viewed,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange,
	(SELECT COUNT(users_id) FROM schmeckt WHERE schmeckt.gerichte_name = gerichte.name AND schmeckt.users_id = login_id) AS tastes
	FROM gerichte
	INNER JOIN versions ON gerichte.name = gerichte_name AND active_id = versions.id 
	INNER JOIN users ON users_id = users.id
	INNER JOIN kategorien ON kategorien_name = kategorien.name 
	GROUP BY gerichte.name ORDER BY viewed DESC LIMIT length;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure newest_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`newest_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `newest_recipes` (IN length INT, IN login_id INT)
BEGIN

SELECT versions.id AS id, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, gerichte.name AS name, personen, kategorien_name, active_id, users_id, nickname, users.image, viewed,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange,
	(SELECT IF(COUNT(users_id) = 1, true, false) FROM schmeckt WHERE schmeckt.gerichte_name = gerichte.name AND schmeckt.users_id = login_id) AS tastes
	FROM gerichte
	INNER JOIN versions ON gerichte.name = gerichte_name AND active_id = versions.id 
	INNER JOIN users ON users_id = users.id
	INNER JOIN kategorien ON kategorien_name = kategorien.name 
	GROUP BY gerichte.name ORDER BY gerichte.eingefuegt DESC LIMIT length;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure user_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`user_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `user_recipes` (IN userId INT, IN login_id INT)
BEGIN

SELECT versions.id AS id, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, gerichte.name AS name, personen, kategorien_name, active_id, users_id, nickname, users.image, COUNT(users_id) AS counter, viewed,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange,
	(SELECT COUNT(users_id) FROM schmeckt WHERE schmeckt.gerichte_name = gerichte.name AND schmeckt.users_id = login_id) AS tastes
	FROM gerichte
	INNER JOIN versions ON gerichte.name = gerichte_name 
	INNER JOIN users ON users_id = users.id
	INNER JOIN kategorien ON kategorien_name = kategorien.name 
	WHERE versions.users_id = userId AND active_id > -1 
	GROUP BY gerichte.name ORDER BY versions.eingefuegt DESC;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure active_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`active_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `active_recipes` ()
BEGIN

SELECT versions.id AS id, gerichte.name AS name, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, personen, kategorien_name, active_id, users_id, users.image, nickname,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange
	FROM gerichte
	INNER JOIN versions ON gerichte.name = gerichte_name AND active_id = versions.id 
	INNER JOIN users ON users_id = users.id
	INNER JOIN kategorien ON kategorien_name = kategorien.name
	WHERE active_id > -1;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure tasting_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`tasting_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `tasting_recipes` (IN user_id INT, IN login_id INT)
BEGIN

SELECT versions.id AS id, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, gerichte.name AS name, personen, kategorien_name, active_id, users.id AS users_id, nickname, users.image, viewed,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange,
	(SELECT IF(COUNT(users_id) = 1, true, false) FROM schmeckt WHERE schmeckt.gerichte_name = gerichte.name AND schmeckt.users_id = login_id) AS tastes
	FROM gerichte
	INNER JOIN versions ON gerichte.name = gerichte_name AND active_id = versions.id 
	INNER JOIN users ON versions.users_id = users.id
	INNER JOIN kategorien ON kategorien_name = kategorien.name
	INNER JOIN schmeckt ON gerichte.name = schmeckt.gerichte_name
	WHERE schmeckt.users_id = user_id GROUP BY name ORDER BY schmeckt.eingefuegt DESC;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure get_version
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`get_version`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`get_version` (IN recipe_name VARCHAR(45), IN version_id INT, IN login_id INT)
BEGIN

SELECT versions.id AS id, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, versions.eingefuegt AS lastChange, 
min, std, skill, kalorien, gerichte.name, personen, kategorien_name, active_id, users_id, nickname, users.image, viewed,
(SELECT IF(COUNT(users_id) = 1, true, false) FROM schmeckt WHERE schmeckt.gerichte_name = gerichte.name AND schmeckt.users_id = login_id) AS tastes
FROM gerichte
INNER JOIN versions ON gerichte.name = gerichte_name
INNER JOIN users ON users_id = users.id
INNER JOIN kategorien ON kategorien_name = kategorien.name 
WHERE gerichte.name = recipe_name AND versions.id = version_id;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure get_all_versions
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`get_all_versions`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`get_all_versions` (IN recipe_name VARCHAR(45), IN login_id INT)
BEGIN

SELECT versions.id AS id, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, gerichte.name, personen, kategorien_name, active_id, users_id, nickname, users.image, viewed, versions.eingefuegt AS lastChange,
	(SELECT COUNT(users_id) FROM schmeckt WHERE schmeckt.gerichte_name = recipe_name AND schmeckt.users_id = login_id) AS tastes
FROM gerichte
INNER JOIN versions ON gerichte.name = gerichte_name
INNER JOIN users ON users_id = users.id
INNER JOIN kategorien ON kategorien_name = kategorien.name 
WHERE gerichte.name = recipe_name;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure get_all_recipes
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`get_all_recipes`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `anycook_db`.`get_all_recipes` (IN login_id INT)
BEGIN

SELECT versions.id AS id, gerichte.name AS name, beschreibung, IFNULL(versions.imagename, CONCAT('category/', kategorien.image)) AS image, gerichte.eingefuegt AS created, 
	min, std, skill, kalorien, personen, kategorien_name, active_id, users_id, users.image, nickname, viewed,
	(SELECT MAX(eingefuegt) FROM versions WHERE gerichte_name = gerichte.name) AS lastChange,
	(SELECT COUNT(users_id) FROM schmeckt WHERE schmeckt.gerichte_name = gerichte.name AND schmeckt.users_id = login_id) AS tastes  
FROM gerichte
INNER JOIN versions ON IF(active_id > 0, gerichte.name = gerichte_name AND active_id = versions.id, gerichte.name = gerichte_name) 
INNER JOIN users ON users_id = users.id
INNER JOIN kategorien ON kategorien_name = kategorien.name
GROUP BY name;

END$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure get_all_users
-- -----------------------------------------------------

USE `anycook_db`;
DROP procedure IF EXISTS `anycook_db`.`get_all_users`;

DELIMITER $$
USE `anycook_db`$$
CREATE PROCEDURE `get_all_users` ()
BEGIN

SELECT id, nickname, facebook_id, email, lastlogin, createdate, image, userlevels_id, text, place, email_candidate FROM users;

END$$

DELIMITER ;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
