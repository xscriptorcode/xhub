-- ============================================================
-- XHUB · Migration 004: Seed Initial Data
-- Creates: Initial roles and sample admin user
-- ============================================================

USE xhub;

-- ============================================================
-- SEED ROLES DATA
-- ============================================================

-- Insert default application roles (if not already exists)
INSERT IGNORE INTO roles(role_name, description) VALUES
  ('admin', 'Administrator with full access to all projects and system management'),
  ('user', 'Standard user with access to own projects and public projects'),
  ('moderator', 'Moderator with limited admin privileges'),
  ('guest', 'Guest user with read-only access to public projects');

-- ============================================================
-- SEED SAMPLE ADMIN USER (Optional - for development)
-- ============================================================

-- Insert sample admin user (password: 'admin123' - change in production!)
-- Note: This is a bcrypt hash of 'admin123' - CHANGE THIS IN PRODUCTION!
INSERT IGNORE INTO users(
  uuid, 
  email, 
  password_hash, 
  full_name, 
  username, 
  bio, 
  is_active
) VALUES (
  UUID(),
  'admin@xhub.local',
  '$2b$10$rQZ8kHWKQVz8KQZ8kHWKQVz8KQZ8kHWKQVz8KQZ8kHWKQVz8KQZ8kH', -- bcrypt hash of 'admin123'
  'System Administrator',
  'admin',
  'Default system administrator account',
  TRUE
);

-- Assign admin role to the admin user
INSERT IGNORE INTO user_roles(user_id, role_id)
SELECT u.id, r.id
FROM users u, roles r
WHERE u.email = 'admin@xhub.local' 
  AND r.role_name = 'admin'
  AND NOT EXISTS (
    SELECT 1 FROM user_roles ur 
    WHERE ur.user_id = u.id AND ur.role_id = r.id
  );

-- ============================================================
-- SEED SAMPLE REGULAR USER (Optional - for development)
-- ============================================================

-- Insert sample regular user (password: 'user123' - change in production!)
INSERT IGNORE INTO users(
  uuid, 
  email, 
  password_hash, 
  full_name, 
  username, 
  bio, 
  is_active
) VALUES (
  UUID(),
  'user@xhub.local',
  '$2b$10$rQZ8kHWKQVz8KQZ8kHWKQVz8KQZ8kHWKQVz8KQZ8kHWKQVz8KQZ8kU', -- bcrypt hash of 'user123'
  'Test User',
  'testuser',
  'Sample user account for testing',
  TRUE
);

-- Assign user role to the test user
INSERT IGNORE INTO user_roles(user_id, role_id)
SELECT u.id, r.id
FROM users u, roles r
WHERE u.email = 'user@xhub.local' 
  AND r.role_name = 'user'
  AND NOT EXISTS (
    SELECT 1 FROM user_roles ur 
    WHERE ur.user_id = u.id AND ur.role_id = r.id
  );

-- ============================================================
-- SEED SAMPLE PROJECT (Optional - for development)
-- ============================================================

-- Create a sample public project
INSERT IGNORE INTO projects(user_id, name, description, visibility)
SELECT u.id, 'Welcome to XHub', 'A sample public project to demonstrate XHub functionality', 'public'
FROM users u
WHERE u.email = 'admin@xhub.local'
  AND NOT EXISTS (
    SELECT 1 FROM projects p 
    WHERE p.name = 'Welcome to XHub' AND p.user_id = u.id
  );

-- Log the project creation
INSERT IGNORE INTO activity_log(user_id, project_id, action, details)
SELECT u.id, p.id, 'create_project', 'Sample project created during database seeding'
FROM users u, projects p
WHERE u.email = 'admin@xhub.local' 
  AND p.name = 'Welcome to XHub' 
  AND p.user_id = u.id
  AND NOT EXISTS (
    SELECT 1 FROM activity_log al 
    WHERE al.user_id = u.id 
      AND al.project_id = p.id 
      AND al.action = 'create_project'
      AND al.details = 'Sample project created during database seeding'
  );

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Show created roles
SELECT 'Created Roles:' as info;
SELECT id, role_name, description, created_at FROM roles ORDER BY id;

-- Show created users
SELECT 'Created Users:' as info;
SELECT id, uuid, email, full_name, username, is_active, created_at FROM users ORDER BY id;

-- Show user role assignments
SELECT 'User Role Assignments:' as info;
SELECT 
  u.username,
  u.email,
  r.role_name,
  ur.assigned_at
FROM user_roles ur
JOIN users u ON u.id = ur.user_id
JOIN roles r ON r.id = ur.role_id
ORDER BY u.username, r.role_name;

-- Show created projects
SELECT 'Created Projects:' as info;
SELECT 
  p.id,
  p.name,
  p.description,
  p.visibility,
  u.username as owner,
  p.created_at
FROM projects p
JOIN users u ON u.id = p.user_id
ORDER BY p.id;

-- Migration completed
SELECT 'Migration 004: Initial data seeded successfully' as status;
SELECT 'IMPORTANT: Change default passwords in production!' as warning;