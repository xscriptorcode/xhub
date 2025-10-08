# XHub Database Migrations

This directory contains the database migrations for the XHub project.

## File Structure

- `001_create_basic_tables.sql` - Creates basic tables (users, roles, projects, files, etc.)
- `002_create_functions_and_procedures.sql` - Creates functions and stored procedures for security policies
- `003_create_roles_views_permissions.sql` - Creates MySQL roles, views, and permissions
- `004_seed_initial_data.sql` - Inserts initial data (roles and test users)
- `run_migrations.sql` - Executes all migrations in order
- `README.md` - This file

## Prerequisites

1. MySQL 8.0 or higher installed and running
2. Administrator access to MySQL (root user)
3. MySQL client (MySQL Workbench, command line, etc.)

## Environment Configuration (example)

1. Make sure the `.env` file in the project root has the correct configuration:
   ```env 
   //example
   DATABASE_URL="mysql://root:password@localhost:3306/xhub"
   DB_HOST=localhost
   DB_PORT=3306
   DB_USER=root
   DB_PASSWORD=password
   DB_NAME=xhub
   ```

2. Adjust the credentials according to your local MySQL configuration.

## Running Migrations

### Option 1: Run all migrations automatically

```sql
-- From MySQL Workbench or command line
SOURCE run_migrations.sql;
```

### Option 2: Run migrations individually

```sql
-- 1. Create basic tables
SOURCE 001_create_basic_tables.sql;

-- 2. Create functions and procedures
SOURCE 002_create_functions_and_procedures.sql;

-- 3. Create roles, views, and permissions
SOURCE 003_create_roles_views_permissions.sql;

-- 4. Insert initial data
SOURCE 004_seed_initial_data.sql;
```

### Option 3: From command line

```bash
# Navigate to migrations directory
cd migrations

# Run all migrations
mysql -u root -p < run_migrations.sql

# Or run individually
mysql -u root -p < 001_create_basic_tables.sql
mysql -u root -p < 002_create_functions_and_procedures.sql
mysql -u root -p < 003_create_roles_views_permissions.sql
mysql -u root -p < 004_seed_initial_data.sql
```

## Test Users Created

The migrations automatically create these users for development:

| Email | Password | Role | Description |
|-------|----------|------|-------------|
| admin@xhub.local | admin123 | admin | System administrator |
| user@xhub.local | user123 | user | Standard user |

**⚠️ IMPORTANT: Change these passwords in production!**

## Created Database Structure

### Main Tables
- `users` - System users
- `roles` - Application roles (admin, user, etc.)
- `user_roles` - User-role relationships
- `projects` - User projects/repositories
- `files` - Files uploaded to projects
- `activity_log` - System activity log

### Security Functions
- `fn_is_user_active()` - Checks if a user is active
- `fn_is_admin()` - Checks if a user is an administrator
- `fn_can_read_project()` - Checks project read permissions
- `fn_can_write_project()` - Checks project write permissions
- `fn_can_write_file()` - Checks file write permissions

### Stored Procedures
- `sp_project_create()` - Create project
- `sp_project_update()` - Update project
- `sp_project_delete()` - Delete project
- `sp_file_upload()` - Upload file
- `sp_file_list_by_project()` - List project files
- `sp_file_delete()` - Delete file
- `sp_log_download()` - Log download

### Security Views
- `v_public_projects` - Public projects
- `v_public_files` - Public project files
- `v_user_projects` - User projects
- `v_user_files` - Files accessible by user

### MySQL Roles
- `xhub_admin` - Full database access
- `xhub_user` - Limited access to procedures and views

## Installation Verification

After running the migrations, you can verify everything is correct:

```sql
-- Check tables
SHOW TABLES;

-- Check created users
SELECT * FROM users;

-- Check roles
SELECT * FROM roles;

-- Check role assignments
SELECT u.username, r.role_name 
FROM user_roles ur
JOIN users u ON u.id = ur.user_id
JOIN roles r ON r.id = ur.role_id;

-- Test a procedure
CALL sp_file_list_by_project(1, 1);
```

## Troubleshooting

### Error: "Table already exists"
Migrations use `CREATE TABLE IF NOT EXISTS`, so it's safe to run them multiple times.

### Error: "Access denied"
Make sure you're connected as root user or with sufficient privileges.

### Error: "Unknown database"
The first migration creates the database automatically.

### Error with functions/procedures
MySQL 8.0+ requires `SUPER` privilege to create functions. Make sure you have the necessary permissions.

## Application Usage

Once migrations are complete, your Next.js application can connect using:

```javascript
// Example with Prisma
DATABASE_URL="mysql://root:password@localhost:3306/xhub"

// Or with direct connection
const connection = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'xhub'
});
```

## Production Security

1. **Change default passwords**
2. **Create application-specific users**
3. **Use SSL connections**
4. **Configure database firewall**
5. **Enable audit logs**
6. **Review and adjust role permissions**