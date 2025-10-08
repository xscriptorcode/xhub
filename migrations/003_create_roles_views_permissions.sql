-- ============================================================
-- XHUB · Migration 003: MySQL Roles, Views, and Permissions
-- Creates: Database roles, security views, and permission grants
-- ============================================================

USE xhub;

-- ============================================================
-- MYSQL DATABASE ROLES (NOT application roles)
-- ============================================================

-- Drop existing roles if they exist (MySQL 8.0+)
DROP ROLE IF EXISTS 'xhub_admin';
DROP ROLE IF EXISTS 'xhub_user';

-- Create MySQL server roles for database access control
CREATE ROLE IF NOT EXISTS 'xhub_admin';
CREATE ROLE IF NOT EXISTS 'xhub_user';

-- ============================================================
-- SECURITY VIEWS
-- ============================================================

-- Drop existing views
DROP VIEW IF EXISTS v_public_projects;
DROP VIEW IF EXISTS v_public_files;
DROP VIEW IF EXISTS v_user_projects;
DROP VIEW IF EXISTS v_user_files;

-- View for public projects (accessible to everyone)
CREATE VIEW v_public_projects AS
SELECT 
  p.id, 
  p.name, 
  p.description, 
  p.visibility, 
  p.user_id, 
  p.created_at, 
  p.updated_at,
  u.username,
  u.full_name,
  (SELECT COUNT(*) FROM files f WHERE f.project_id = p.id) as file_count
FROM projects p
JOIN users u ON u.id = p.user_id
WHERE p.visibility = 'public' AND u.is_active = TRUE;

-- View for public files (from public projects only)
CREATE VIEW v_public_files AS
SELECT 
  f.id, 
  f.project_id, 
  f.filename, 
  f.version, 
  f.size, 
  f.mimetype, 
  f.uploaded_at, 
  f.user_id,
  p.name as project_name,
  p.visibility,
  u.username,
  u.full_name
FROM files f
JOIN projects p ON p.id = f.project_id
JOIN users u ON u.id = f.user_id
WHERE p.visibility = 'public' AND u.is_active = TRUE;

-- View for user's own projects (requires filtering by user_id in application)
CREATE VIEW v_user_projects AS
SELECT 
  p.id, 
  p.name, 
  p.description, 
  p.visibility, 
  p.user_id, 
  p.created_at, 
  p.updated_at,
  u.username,
  u.full_name,
  (SELECT COUNT(*) FROM files f WHERE f.project_id = p.id) as file_count
FROM projects p
JOIN users u ON u.id = p.user_id
WHERE u.is_active = TRUE;

-- View for user's accessible files (requires filtering by user permissions in application)
CREATE VIEW v_user_files AS
SELECT 
  f.id, 
  f.project_id, 
  f.filename, 
  f.version, 
  f.size, 
  f.mimetype, 
  f.uploaded_at, 
  f.user_id,
  p.name as project_name,
  p.visibility,
  p.user_id as project_owner_id,
  u.username,
  u.full_name
FROM files f
JOIN projects p ON p.id = f.project_id
JOIN users u ON u.id = f.user_id
WHERE u.is_active = TRUE;

-- ============================================================
-- TRIGGERS FOR ADDITIONAL SECURITY
-- ============================================================

-- Drop existing triggers
DROP TRIGGER IF EXISTS trg_users_audit;
DROP TRIGGER IF EXISTS trg_projects_audit;
DROP TRIGGER IF EXISTS trg_files_audit;

DELIMITER //

-- Audit trigger for user changes
CREATE TRIGGER trg_users_audit
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
  IF OLD.is_active != NEW.is_active THEN
    INSERT INTO activity_log(user_id, action, details)
    VALUES (NEW.id, 'edit', CONCAT('User status changed: ', IF(NEW.is_active, 'activated', 'deactivated')));
  END IF;
END//

-- Audit trigger for project visibility changes
CREATE TRIGGER trg_projects_audit
AFTER UPDATE ON projects
FOR EACH ROW
BEGIN
  IF OLD.visibility != NEW.visibility THEN
    INSERT INTO activity_log(user_id, project_id, action, details)
    VALUES (NEW.user_id, NEW.id, 'update_project', CONCAT('Visibility changed from ', OLD.visibility, ' to ', NEW.visibility));
  END IF;
END//

DELIMITER ;

-- ============================================================
-- PERMISSIONS AND GRANTS
-- ============================================================

-- First, revoke all existing privileges for security
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'xhub_user'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'xhub_admin'@'%';

-- Grant permissions to xhub_user role (limited access)
-- Can execute stored procedures for safe data access
GRANT EXECUTE ON PROCEDURE xhub.sp_project_create TO 'xhub_user';
GRANT EXECUTE ON PROCEDURE xhub.sp_project_update TO 'xhub_user';
GRANT EXECUTE ON PROCEDURE xhub.sp_project_delete TO 'xhub_user';
GRANT EXECUTE ON PROCEDURE xhub.sp_file_upload TO 'xhub_user';
GRANT EXECUTE ON PROCEDURE xhub.sp_file_list_by_project TO 'xhub_user';
GRANT EXECUTE ON PROCEDURE xhub.sp_file_delete TO 'xhub_user';
GRANT EXECUTE ON PROCEDURE xhub.sp_log_download TO 'xhub_user';

-- Can read public views
GRANT SELECT ON xhub.v_public_projects TO 'xhub_user';
GRANT SELECT ON xhub.v_public_files TO 'xhub_user';

-- Can read user views (application must filter by user_id)
GRANT SELECT ON xhub.v_user_projects TO 'xhub_user';
GRANT SELECT ON xhub.v_user_files TO 'xhub_user';

-- Limited direct table access for authentication and basic operations
GRANT SELECT ON xhub.users TO 'xhub_user';
GRANT SELECT ON xhub.roles TO 'xhub_user';
GRANT SELECT ON xhub.user_roles TO 'xhub_user';

-- Grant permissions to xhub_admin role (full access)
GRANT ALL PRIVILEGES ON xhub.* TO 'xhub_admin';

-- ============================================================
-- EXAMPLE USER CREATION (commented out - create as needed)
-- ============================================================

/*
-- Example: Create application users and assign roles
CREATE USER IF NOT EXISTS 'xhub_app_user'@'localhost' IDENTIFIED BY 'secure_password_here';
CREATE USER IF NOT EXISTS 'xhub_app_admin'@'localhost' IDENTIFIED BY 'admin_password_here';

-- Assign roles to users
GRANT 'xhub_user' TO 'xhub_app_user'@'localhost';
GRANT 'xhub_admin' TO 'xhub_app_admin'@'localhost';

-- Set default roles
SET DEFAULT ROLE 'xhub_user' TO 'xhub_app_user'@'localhost';
SET DEFAULT ROLE 'xhub_admin' TO 'xhub_app_admin'@'localhost';

-- For remote connections (adjust host as needed)
CREATE USER IF NOT EXISTS 'xhub_app_user'@'%' IDENTIFIED BY 'secure_password_here';
GRANT 'xhub_user' TO 'xhub_app_user'@'%';
SET DEFAULT ROLE 'xhub_user' TO 'xhub_app_user'@'%';
*/

-- ============================================================
-- ADDITIONAL SECURITY CONFIGURATIONS
-- ============================================================

-- Create indexes for better performance on security-related queries
CREATE INDEX IF NOT EXISTS idx_activity_log_user_action ON activity_log(user_id, action);
CREATE INDEX IF NOT EXISTS idx_activity_log_created_desc ON activity_log(created_at DESC);

-- Migration completed
SELECT 'Migration 003: MySQL roles, views, and permissions created successfully' as status;