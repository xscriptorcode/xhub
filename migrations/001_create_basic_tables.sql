-- ============================================================
-- XHUB · Migration 001: Basic Tables Structure
-- Creates: users, roles, user_roles, projects, files, activity_log
-- ============================================================

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS xhub CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE xhub;

-- 1. Users table
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  uuid CHAR(36) NOT NULL UNIQUE,           -- UUID v4 
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(255),
  username VARCHAR(100) UNIQUE,
  avatar_url TEXT,
  bio TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Indexes for performance
  INDEX idx_users_email (email),
  INDEX idx_users_username (username),
  INDEX idx_users_uuid (uuid),
  INDEX idx_users_is_active (is_active)
);

-- 2. Roles table
CREATE TABLE IF NOT EXISTS roles (
  id INT AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(50) UNIQUE NOT NULL,   -- admin, user, guest, etc.
  description VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Indexes
  INDEX idx_roles_name (role_name)
);

-- 3. User roles relationship table
CREATE TABLE IF NOT EXISTS user_roles (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  role_id INT NOT NULL,
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign keys
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  
  -- Indexes
  INDEX idx_user_roles_user (user_id),
  INDEX idx_user_roles_role (role_id),
  UNIQUE KEY uk_user_role (user_id, role_id)
);

-- 4. Projects table
CREATE TABLE IF NOT EXISTS projects (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  visibility ENUM('public', 'private') DEFAULT 'private',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Foreign keys
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  
  -- Indexes
  INDEX idx_projects_user (user_id),
  INDEX idx_projects_visibility (visibility),
  INDEX idx_projects_name (name)
);

-- 5. Files table
CREATE TABLE IF NOT EXISTS files (
  id INT AUTO_INCREMENT PRIMARY KEY,
  project_id INT NOT NULL,
  user_id INT NOT NULL,
  filename VARCHAR(255) NOT NULL,
  filepath TEXT NOT NULL,               -- ruta o URL en disco/VPS
  mimetype VARCHAR(100),
  size BIGINT,
  version INT DEFAULT 1,
  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign keys
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  
  -- Indexes
  INDEX idx_files_project (project_id),
  INDEX idx_files_user (user_id),
  INDEX idx_files_filename (filename),
  INDEX idx_files_version (version),
  INDEX idx_files_uploaded (uploaded_at)
);

-- 6. Activity log table
CREATE TABLE IF NOT EXISTS activity_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  project_id INT,
  file_id INT,
  action ENUM('upload', 'download', 'delete', 'edit', 'login', 'logout', 'create_project', 'update_project', 'delete_project') NOT NULL,
  details TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign keys
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE SET NULL,
  
  -- Indexes
  INDEX idx_activity_user (user_id),
  INDEX idx_activity_project (project_id),
  INDEX idx_activity_file (file_id),
  INDEX idx_activity_action (action),
  INDEX idx_activity_created (created_at)
);

-- Insert default roles
INSERT IGNORE INTO roles(role_name, description) VALUES
  ('admin', 'Administrator with full access'),
  ('user', 'Standard user with limited access');

-- Migration completed
SELECT 'Migration 001: Basic tables created successfully' as status;