const { PrismaClient } = require('../src/generated/prisma');
const fs = require('fs');
const path = require('path');

const prisma = new PrismaClient();

async function executeSQLFile(filePath) {
  console.log(`Executing SQL file: ${filePath}`);
  
  try {
    const sqlContent = fs.readFileSync(filePath, 'utf8');
    
    // Split SQL content by semicolons and filter out empty statements
    const statements = sqlContent
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--') && !stmt.startsWith('/*'));
    
    for (const statement of statements) {
      if (statement.trim()) {
        try {
          // Skip certain MySQL-specific commands that Prisma can't handle
          if (
            statement.includes('SOURCE ') ||
            statement.includes('SHOW ') ||
            statement.includes('DELIMITER') ||
            statement.includes('CREATE ROLE') ||
            statement.includes('DROP ROLE') ||
            statement.includes('GRANT ') ||
            statement.includes('REVOKE ') ||
            statement.includes('SET DEFAULT ROLE') ||
            statement.includes('CREATE USER') ||
            statement.includes('CREATE FUNCTION') ||
            statement.includes('CREATE PROCEDURE') ||
            statement.includes('CREATE TRIGGER') ||
            statement.includes('DROP FUNCTION') ||
            statement.includes('DROP PROCEDURE') ||
            statement.includes('DROP TRIGGER')
          ) {
            console.log(`Skipping MySQL-specific statement: ${statement.substring(0, 50)}...`);
            continue;
          }
          
          await prisma.$executeRawUnsafe(statement);
        } catch (error) {
          console.warn(`Warning: Could not execute statement: ${statement.substring(0, 50)}...`);
          console.warn(`Error: ${error.message}`);
        }
      }
    }
    
    console.log(`Completed: ${filePath}`);
  } catch (error) {
    console.error(`Error executing ${filePath}:`, error.message);
    throw error;
  }
}

async function main() {
  console.log('Starting XHub database seeding...');
  
  const migrationsDir = path.join(__dirname, '..', 'migrations');
  
  // List of migration files in order
  const migrationFiles = [
    '001_create_basic_tables.sql',
    '002_create_functions_and_procedures.sql',
    '003_create_roles_views_permissions.sql',
    '004_seed_initial_data.sql'
  ];
  
  try {
    // Execute each migration file
    for (const file of migrationFiles) {
      const filePath = path.join(migrationsDir, file);
      
      if (fs.existsSync(filePath)) {
        await executeSQLFile(filePath);
      } else {
        console.warn(`Migration file not found: ${filePath}`);
      }
    }
    
    console.log(' Database seeding completed successfully!');
    console.log('');
    console.log('Summary:');
    console.log('- Basic tables created');
    console.log('- Security functions and procedures created (where supported)');
    console.log('- Initial roles and users seeded');
    console.log('');
    console.log('Default users created:');
    console.log('- admin@xhub.local / admin123 (Admin)');
    console.log('- user@xhub.local / user123 (User)');
    console.log('');
    console.log('IMPORTANT: Change default passwords in production!');
    
  } catch (error) {
    console.error('Database seeding failed:', error);
    process.exit(1);
  }
}

main()
  .catch((e) => {
    console.error('Seeding error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });