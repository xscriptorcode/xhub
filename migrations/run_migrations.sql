-- ============================================================
-- XHUB · Master Migration Runner
-- Executes all migrations in the correct order
-- ============================================================

-- Set SQL mode for compatibility
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- Show current timestamp
SELECT CONCAT('Starting XHub database setup at: ', NOW()) as info;

-- ============================================================
-- MIGRATION 001: Basic Tables Structure
-- ============================================================
SELECT 'Running Migration 001: Basic Tables Structure...' as status;
SOURCE 001_create_basic_tables.sql;

-- ============================================================
-- MIGRATION 002: Functions and Stored Procedures
-- ============================================================
SELECT 'Running Migration 002: Functions and Stored Procedures...' as status;
SOURCE 002_create_functions_and_procedures.sql;

-- ============================================================
-- MIGRATION 003: MySQL Roles, Views, and Permissions
-- ============================================================
SELECT 'Running Migration 003: MySQL Roles, Views, and Permissions...' as status;
SOURCE 003_create_roles_views_permissions.sql;

-- ============================================================
-- MIGRATION 004: Seed Initial Data
-- ============================================================
SELECT 'Running Migration 004: Seed Initial Data...' as status;
SOURCE 004_seed_initial_data.sql;

-- ============================================================
-- FINAL VERIFICATION
-- ============================================================
SELECT 'Verifying database setup...' as status;

-- Check tables
SELECT 'Database Tables:' as info;
SHOW TABLES;

-- Check functions
SELECT 'Database Functions:' as info;
SELECT ROUTINE_NAME, ROUTINE_TYPE 
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_SCHEMA = 'xhub' AND ROUTINE_TYPE = 'FUNCTION'
ORDER BY ROUTINE_NAME;

-- Check procedures
SELECT 'Database Procedures:' as info;
SELECT ROUTINE_NAME, ROUTINE_TYPE 
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_SCHEMA = 'xhub' AND ROUTINE_TYPE = 'PROCEDURE'
ORDER BY ROUTINE_NAME;

-- Check views
SELECT 'Database Views:' as info;
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'xhub'
ORDER BY TABLE_NAME;

-- Check roles (MySQL 8.0+)
SELECT 'MySQL Roles:' as info;
SHOW GRANTS FOR 'xhub_admin';
SHOW GRANTS FOR 'xhub_user';

-- Final status
SELECT CONCAT('XHub database setup completed successfully at: ', NOW()) as final_status;
SELECT 'You can now connect your application using the credentials in .env file' as next_steps;

-- ============================================================
-- USAGE INSTRUCTIONS
-- ============================================================
/*
To run this migration:

1. Make sure MySQL is running
2. Open MySQL command line or MySQL Workbench
3. Navigate to the migrations directory
4. Run: SOURCE run_migrations.sql;

Or run each migration individually:
- SOURCE 001_create_basic_tables.sql;
- SOURCE 002_create_functions_and_procedures.sql;
- SOURCE 003_create_roles_views_permissions.sql;
- SOURCE 004_seed_initial_data.sql;

Default credentials created:
- Admin: admin@xhub.local / admin123
- User: user@xhub.local / user123

IMPORTANT: Change these passwords in production!
*/