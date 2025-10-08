-- ============================================================
-- XHUB · Migration 002: Functions and Stored Procedures
-- Creates: Security functions and stored procedures for policies
-- ============================================================

USE xhub;

-- Drop existing functions and procedures if they exist
DROP FUNCTION IF EXISTS fn_is_user_active;
DROP FUNCTION IF EXISTS fn_is_admin;
DROP FUNCTION IF EXISTS fn_can_read_project;
DROP FUNCTION IF EXISTS fn_can_write_file;
DROP FUNCTION IF EXISTS fn_can_write_project;

DROP PROCEDURE IF EXISTS sp_project_create;
DROP PROCEDURE IF EXISTS sp_project_update;
DROP PROCEDURE IF EXISTS sp_project_delete;
DROP PROCEDURE IF EXISTS sp_file_upload;
DROP PROCEDURE IF EXISTS sp_file_list_by_project;
DROP PROCEDURE IF EXISTS sp_file_delete;
DROP PROCEDURE IF EXISTS sp_log_download;

-- ============================================================
-- SECURITY FUNCTIONS
-- ============================================================

DELIMITER //

-- Check if user is active
CREATE FUNCTION fn_is_user_active(p_user_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_active BOOLEAN DEFAULT FALSE;
  SELECT is_active INTO v_active FROM users WHERE id = p_user_id;
  RETURN IFNULL(v_active, FALSE);
END//

-- Check if user is admin (according to application roles table)
CREATE FUNCTION fn_is_admin(p_user_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = p_user_id
      AND r.role_name = 'admin'
  );
END//

-- Check if user can read a project (by visibility/ownership)
CREATE FUNCTION fn_can_read_project(p_project_id INT, p_requester_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM projects p
    WHERE p.id = p_project_id
      AND (
        p.visibility = 'public'
        OR p.user_id = p_requester_id
        OR fn_is_admin(p_requester_id) = TRUE
      )
  );
END//

-- Check if user can write/modify a file (owner or admin)
CREATE FUNCTION fn_can_write_file(p_file_id INT, p_requester_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM files f
    WHERE f.id = p_file_id
      AND (
        f.user_id = p_requester_id
        OR fn_is_admin(p_requester_id) = TRUE
      )
  );
END//

-- Check if user can write to a project (owner or admin)
CREATE FUNCTION fn_can_write_project(p_project_id INT, p_requester_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM projects p
    WHERE p.id = p_project_id
      AND (
        p.user_id = p_requester_id
        OR fn_is_admin(p_requester_id) = TRUE
      )
  );
END//

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- Create a new project
CREATE PROCEDURE sp_project_create(
  IN p_user_id INT,
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_visibility ENUM('public','private')
)
BEGIN
  DECLARE v_project_id INT;
  
  -- Check if user is active
  IF NOT fn_is_user_active(p_user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not active';
  END IF;

  -- Insert project
  INSERT INTO projects(user_id, name, description, visibility)
  VALUES (p_user_id, p_name, p_description, COALESCE(p_visibility,'private'));
  
  SET v_project_id = LAST_INSERT_ID();

  -- Log activity
  INSERT INTO activity_log(user_id, project_id, action, details)
  VALUES (p_user_id, v_project_id, 'create_project', CONCAT('Project created: ', p_name));
  
  -- Return project ID
  SELECT v_project_id as project_id;
END//

-- Update an existing project (only owner or admin)
CREATE PROCEDURE sp_project_update(
  IN p_requester_id INT,
  IN p_project_id INT,
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_visibility ENUM('public','private')
)
BEGIN
  -- Check permissions
  IF NOT fn_can_write_project(p_project_id, p_requester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forbidden: not project owner/admin';
  END IF;

  -- Update project
  UPDATE projects
     SET name = COALESCE(p_name, name),
         description = COALESCE(p_description, description),
         visibility = COALESCE(p_visibility, visibility),
         updated_at = CURRENT_TIMESTAMP
   WHERE id = p_project_id;

  -- Log activity
  INSERT INTO activity_log(user_id, project_id, action, details)
  VALUES (p_requester_id, p_project_id, 'update_project', 'Project updated');
  
  SELECT 'Project updated successfully' as status;
END//

-- Delete a project (only owner or admin)
CREATE PROCEDURE sp_project_delete(
  IN p_requester_id INT,
  IN p_project_id INT
)
BEGIN
  DECLARE v_project_name VARCHAR(255);
  
  -- Check permissions
  IF NOT fn_can_write_project(p_project_id, p_requester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forbidden: not project owner/admin';
  END IF;

  -- Get project name for logging
  SELECT name INTO v_project_name FROM projects WHERE id = p_project_id;

  -- Delete project (cascade will handle related records)
  DELETE FROM projects WHERE id = p_project_id;

  -- Log activity
  INSERT INTO activity_log(user_id, project_id, action, details)
  VALUES (p_requester_id, p_project_id, 'delete_project', CONCAT('Project deleted: ', v_project_name));
  
  SELECT 'Project deleted successfully' as status;
END//

-- Upload a file (creates version if filename already exists)
CREATE PROCEDURE sp_file_upload(
  IN p_requester_id INT,
  IN p_project_id INT,
  IN p_filename VARCHAR(255),
  IN p_filepath TEXT,
  IN p_mimetype VARCHAR(100),
  IN p_size BIGINT
)
BEGIN
  DECLARE v_next_version INT DEFAULT 1;
  DECLARE v_file_id INT;

  -- Check if user is active
  IF NOT fn_is_user_active(p_requester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not active';
  END IF;

  -- Check if user can write to project
  IF NOT fn_can_write_project(p_project_id, p_requester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forbidden: not project owner/admin';
  END IF;

  -- Get next version number for this filename in this project
  SELECT COALESCE(MAX(version) + 1, 1)
    INTO v_next_version
    FROM files
   WHERE project_id = p_project_id
     AND filename = p_filename;

  -- Insert file
  INSERT INTO files(project_id, user_id, filename, filepath, mimetype, size, version)
  VALUES (p_project_id, p_requester_id, p_filename, p_filepath, p_mimetype, p_size, v_next_version);
  
  SET v_file_id = LAST_INSERT_ID();

  -- Log activity
  INSERT INTO activity_log(user_id, project_id, file_id, action, details)
  VALUES (p_requester_id, p_project_id, v_file_id, 'upload', CONCAT('Upload ', p_filename, ' v', v_next_version));
  
  -- Return file info
  SELECT v_file_id as file_id, v_next_version as version;
END//

-- List files in a project with read access control
CREATE PROCEDURE sp_file_list_by_project(
  IN p_requester_id INT,
  IN p_project_id INT
)
BEGIN
  -- Check if user can read project
  IF NOT fn_can_read_project(p_project_id, p_requester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forbidden: cannot read project';
  END IF;

  -- Return files list
  SELECT f.id, f.filename, f.version, f.size, f.mimetype, f.uploaded_at, f.user_id,
         p.id AS project_id, p.name AS project_name, p.visibility,
         u.username, u.full_name
    FROM files f
    JOIN projects p ON p.id = f.project_id
    JOIN users u ON u.id = f.user_id
   WHERE f.project_id = p_project_id
   ORDER BY f.filename, f.version DESC;
END//

-- Delete a file (file owner or admin only)
CREATE PROCEDURE sp_file_delete(
  IN p_requester_id INT,
  IN p_file_id INT
)
BEGIN
  DECLARE v_project_id INT;
  DECLARE v_filename VARCHAR(255);

  -- Check permissions
  IF NOT fn_can_write_file(p_file_id, p_requester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forbidden: not file owner/admin';
  END IF;

  -- Get file info for logging
  SELECT project_id, filename INTO v_project_id, v_filename FROM files WHERE id = p_file_id;

  -- Delete file
  DELETE FROM files WHERE id = p_file_id;

  -- Log activity
  INSERT INTO activity_log(user_id, project_id, file_id, action, details)
  VALUES (p_requester_id, v_project_id, p_file_id, 'delete', CONCAT('Delete ', v_filename));
  
  SELECT 'File deleted successfully' as status;
END//

-- Log file download (doesn't deliver file; that's handled by the app)
CREATE PROCEDURE sp_log_download(
  IN p_requester_id INT,
  IN p_file_id INT
)
BEGIN
  DECLARE v_project_id INT;
  DECLARE v_filename VARCHAR(255);

  -- Get project ID from file
  SELECT f.project_id, f.filename INTO v_project_id, v_filename
    FROM files f
   WHERE f.id = p_file_id;

  -- Check if user can read the project containing this file
  IF v_project_id IS NULL OR NOT fn_can_read_project(v_project_id, p_requester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forbidden: cannot read file/project';
  END IF;

  -- Log download activity
  INSERT INTO activity_log(user_id, project_id, file_id, action, details)
  VALUES (p_requester_id, v_project_id, p_file_id, 'download', CONCAT('Downloaded: ', v_filename));
  
  SELECT 'Download logged successfully' as status;
END//

DELIMITER ;

-- Migration completed
SELECT 'Migration 002: Functions and stored procedures created successfully' as status;