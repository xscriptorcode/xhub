# XHub Database Configuration

This guide explains how to configure the XHub database using both direct SQL migrations and Prisma integration.

## Option 1: Using Prisma (Recommended for development)

### 1. Install MySQL dependencies

```bash
npm install mysql2
```

### 2. Configure environment variables

Make sure your `.env` file has the correct configuration:

```env
DATABASE_URL="mysql://root:password@localhost:3306/xhub"
```

### 3. Run database configuration

```bash
# Option A: Complete automatic configuration
npm run db:setup

# Option B: Step by step
npm run db:migrate    # Synchronizes Prisma schema with DB
npm run db:generate   # Generates Prisma client
npm run db:seed       # Executes SQL migrations and initial data
```

### 4. Verify installation

```bash
# Open Prisma Studio to view data
npm run db:studio
```

## Option 2: Using direct SQL (For production)

### 1. Run migrations manually

```bash
# From MySQL Workbench or command line
cd migrations
mysql -u root -p < run_migrations.sql
```

### 2. Synchronize Prisma with existing database

```bash
# Generate client based on existing DB
npx prisma db pull
npx prisma generate
```

## Available scripts

| Command | Description |
|---------|-------------|
| `npm run db:setup` | Complete configuration (migrate + generate) |
| `npm run db:migrate` | Synchronizes Prisma schema with DB |
| `npm run db:generate` | Generates Prisma client |
| `npm run db:seed` | Executes SQL migrations and initial data |
| `npm run db:studio` | Opens Prisma Studio visual interface |
| `npm run db:reset` | Completely resets the database |

## Project structure

```
xhub/
├── .env                          # Environment variables
├── prisma/
│   ├── schema.prisma            # Prisma schema (synchronized with SQL)
│   └── seed.js                  # Seeding script that executes SQL migrations
├── migrations/                  # Original SQL migrations
│   ├── 001_create_basic_tables.sql
│   ├── 002_create_functions_and_procedures.sql
│   ├── 003_create_roles_views_permissions.sql
│   ├── 004_seed_initial_data.sql
│   └── run_migrations.sql
└── src/generated/prisma/        # Generated Prisma client
```

## Recommended workflow

### For local development:

1. **First time:**
   ```bash
   npm install mysql2
   npm run db:setup
   npm run db:seed
   ```

2. **Schema changes:**
   ```bash
   # Edit prisma/schema.prisma
   npm run db:migrate
   npm run db:generate
   ```

3. **Reset database:**
   ```bash
   npm run db:reset
   npm run db:seed
   ```

### For production:

1. **Execute SQL migrations directly:**
   ```bash
   mysql -u root -p < migrations/run_migrations.sql
   ```

2. **Generate Prisma client:**
   ```bash
   npx prisma generate
   ```

## Implemented features

**Prisma schema** synchronized with SQL migrations  
**Functions and procedures** (limited by Prisma)  
**Initial data** with test users  
**Automated scripts** for development  
**Compatibility** with MySQL 8.0+  

## Prisma limitations

Prisma does not fully support:
- MySQL stored functions
- Complex stored procedures
- MySQL roles
- Advanced triggers

For these features, use direct SQL migrations or execute raw SQL with `prisma.$executeRaw()`.

## Test users

| Email | Password | Role |
|-------|----------|------|
| admin@xhub.local | admin123 | admin |
| user@xhub.local | user123 | user |

**⚠️ Change passwords in production!**

## Troubleshooting

### Error: "Table doesn't exist"
```bash
npm run db:migrate
```

### Error: "Client not generated"
```bash
npm run db:generate
```

### Error: "Connection refused"
- Verify that MySQL is running
- Verify credentials in `.env`

### Error: "Access denied"
- Verify MySQL user permissions
- Use root user for initial migrations

## Application usage

```typescript
// src/lib/prisma.ts
import { PrismaClient } from '@/generated/prisma';

const prisma = new PrismaClient();

// Usage example
const users = await prisma.user.findMany({
  include: {
    userRoles: {
      include: {
        role: true
      }
    }
  }
});

// For complex SQL functions, use raw SQL
const result = await prisma.$executeRaw`
  CALL sp_project_create(${userId}, ${name}, ${description}, ${visibility})
`;
```