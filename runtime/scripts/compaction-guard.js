#!/usr/bin/env node
/**
 * Compaction Guard
 * 
 * Anti-compaction protection system that:
 * - Monitors for context loss indicators
 * - Validates context integrity before and after operations
 * - Reconstructs lost context from backups if needed
 * - Maintains multiple redundant copies
 * 
 * This is the safety net that ensures context is NEVER lost.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Configuration
const CONFIG = {
  workspaceDir: process.env.HENRY_WORKSPACE || path.join(process.env.HOME, '.openclaw/workspace'),
  memoryDir: process.env.HENRY_MEMORY || path.join(process.env.HOME, '.openclaw/memory'),
  backupsDir: path.join(process.env.HOME, '.openclaw/.context-backups'),
  guardFile: path.join(process.env.HOME, '.openclaw/.compaction-guard.json'),
  integrityLog: path.join(process.env.HOME, '.openclaw/.integrity-log.jsonl'),
  minBackups: 5,
  maxBackups: 50,
  criticalFiles: [
    'PROJECT-CONTEXT.md',
    'WORKSPACE-MEMORY.md',
    'SOUL.md',
    'MEMORY.md',
    'AGENTS.md',
  ],
};

// Ensure directories exist
[CONFIG.backupsDir, CONFIG.memoryDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

const now = () => new Date().toISOString();
const log = (level, message) => {
  const entry = { timestamp: now(), level, message };
  console.log(`[${entry.timestamp}] [${level.toUpperCase()}] ${message}`);
  
  // Append to integrity log
  fs.appendFileSync(CONFIG.integrityLog, JSON.stringify(entry) + '\n');
};

/**
 * Compaction Guard - Context Loss Prevention System
 */
class CompactionGuard {
  constructor() {
    this.guardState = this.loadGuardState();
    this.checksums = new Map();
  }

  loadGuardState() {
    if (fs.existsSync(CONFIG.guardFile)) {
      return JSON.parse(fs.readFileSync(CONFIG.guardFile, 'utf-8'));
    }
    return {
      initialized: now(),
      lastCheck: null,
      checksPassed: 0,
      checksFailed: 0,
      recoveries: 0,
      criticalFiles: {},
    };
  }

  saveGuardState() {
    this.guardState.lastCheck = now();
    fs.writeFileSync(CONFIG.guardFile, JSON.stringify(this.guardState, null, 2));
  }

  /**
   * Calculate file checksum for integrity verification
   */
  calculateChecksum(filePath) {
    try {
      const content = fs.readFileSync(filePath);
      return crypto.createHash('sha256').update(content).digest('hex');
    } catch {
      return null;
    }
  }

  /**
   * Create a snapshot of critical files
   */
  createSnapshot(label = 'auto') {
    const snapshotId = `${label}-${Date.now()}`;
    const snapshotDir = path.join(CONFIG.backupsDir, snapshotId);
    
    fs.mkdirSync(snapshotDir, { recursive: true });

    const snapshot = {
      id: snapshotId,
      timestamp: now(),
      label,
      files: {},
    };

    for (const file of CONFIG.criticalFiles) {
      const sourcePath = path.join(CONFIG.workspaceDir, file);
      if (fs.existsSync(sourcePath)) {
        const backupPath = path.join(snapshotDir, file);
        fs.copyFileSync(sourcePath, backupPath);
        snapshot.files[file] = {
          size: fs.statSync(sourcePath).size,
          checksum: this.calculateChecksum(sourcePath),
        };
      }
    }

    // Also backup memory files
    const memorySnapshotDir = path.join(snapshotDir, 'memory');
    fs.mkdirSync(memorySnapshotDir, { recursive: true });
    
    const memoryFiles = fs.readdirSync(CONFIG.memoryDir).filter(f => f.endsWith('.md'));
    for (const file of memoryFiles.slice(-10)) { // Last 10 memory files
      const sourcePath = path.join(CONFIG.memoryDir, file);
      const backupPath = path.join(memorySnapshotDir, file);
      fs.copyFileSync(sourcePath, backupPath);
    }

    // Save snapshot manifest
    fs.writeFileSync(
      path.join(snapshotDir, 'manifest.json'),
      JSON.stringify(snapshot, null, 2)
    );

    log('info', `Created snapshot: ${snapshotId}`);
    this.cleanupOldSnapshots();
    
    return snapshot;
  }

  /**
   * Clean up old snapshots, keeping only the most recent
   */
  cleanupOldSnapshots() {
    try {
      const snapshots = fs.readdirSync(CONFIG.backupsDir)
        .filter(dir => dir !== '.' && dir !== '..')
        .map(dir => ({
          name: dir,
          path: path.join(CONFIG.backupsDir, dir),
          stat: fs.statSync(path.join(CONFIG.backupsDir, dir)),
        }))
        .sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);

      // Keep only maxBackups
      if (snapshots.length > CONFIG.maxBackups) {
        for (const snapshot of snapshots.slice(CONFIG.maxBackups)) {
          fs.rmSync(snapshot.path, { recursive: true, force: true });
          log('info', `Cleaned up old snapshot: ${snapshot.name}`);
        }
      }
    } catch (err) {
      log('warning', `Cleanup failed: ${err.message}`);
    }
  }

  /**
   * Validate context integrity
   */
  validate() {
    log('info', 'Starting context integrity validation...');

    const issues = [];
    const results = {
      timestamp: now(),
      passed: true,
      checks: {},
      issues: [],
    };

    // Check 1: Critical files exist
    results.checks.criticalFilesExist = { passed: true, details: [] };
    for (const file of CONFIG.criticalFiles) {
      const filePath = path.join(CONFIG.workspaceDir, file);
      const exists = fs.existsSync(filePath);
      results.checks.criticalFilesExist.details.push({ file, exists });
      if (!exists) {
        issues.push(`Missing critical file: ${file}`);
        results.checks.criticalFilesExist.passed = false;
      }
    }

    // Check 2: Files are not empty
    results.checks.filesNotEmpty = { passed: true, details: [] };
    for (const file of CONFIG.criticalFiles) {
      const filePath = path.join(CONFIG.workspaceDir, file);
      if (fs.existsSync(filePath)) {
        const size = fs.statSync(filePath).size;
        results.checks.filesNotEmpty.details.push({ file, size });
        if (size === 0) {
          issues.push(`Empty critical file: ${file}`);
          results.checks.filesNotEmpty.passed = false;
        }
      }
    }

    // Check 3: Checksum validation (detect corruption)
    results.checks.checksumsValid = { passed: true, details: [] };
    for (const [file, state] of Object.entries(this.guardState.criticalFiles)) {
      const filePath = path.join(CONFIG.workspaceDir, file);
      if (fs.existsSync(filePath)) {
        const currentChecksum = this.calculateChecksum(filePath);
        const previousChecksum = state.checksum;
        const checksumValid = !previousChecksum || currentChecksum === previousChecksum;
        
        results.checks.checksumsValid.details.push({
          file,
          previous: previousChecksum?.substring(0, 16) + '...',
          current: currentChecksum?.substring(0, 16) + '...',
          valid: checksumValid,
        });

        if (!checksumValid) {
          // File changed - this might be ok if it was intentional
          log('info', `File changed (may be intentional): ${file}`);
        }
      }
    }

    // Check 4: Minimum backup count
    results.checks.backupCount = { passed: true, count: 0 };
    try {
      const backups = fs.readdirSync(CONFIG.backupsDir).filter(
        dir => fs.statSync(path.join(CONFIG.backupsDir, dir)).isDirectory()
      );
      results.checks.backupCount.count = backups.length;
      if (backups.length < CONFIG.minBackups) {
        issues.push(`Insufficient backups: ${backups.length} < ${CONFIG.minBackups}`);
        results.checks.backupCount.passed = false;
      }
    } catch {
      issues.push('Cannot access backups directory');
      results.checks.backupCount.passed = false;
    }

    // Check 5: Recent backup exists (within 24 hours)
    results.checks.recentBackup = { passed: false, age: null };
    try {
      const snapshots = fs.readdirSync(CONFIG.backupsDir)
        .map(dir => ({
          name: dir,
          stat: fs.statSync(path.join(CONFIG.backupsDir, dir)),
        }))
        .sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);

      if (snapshots.length > 0) {
        const age = Date.now() - snapshots[0].stat.mtimeMs;
        const ageHours = age / (1000 * 60 * 60);
        results.checks.recentBackup.age = ageHours;
        results.checks.recentBackup.passed = ageHours < 24;
        
        if (!results.checks.recentBackup.passed) {
          issues.push(`No recent backup: last backup is ${ageHours.toFixed(1)} hours old`);
        }
      } else {
        issues.push('No backups found');
      }
    } catch {
      issues.push('Cannot check backup age');
    }

    // Check 6: Memory files exist
    results.checks.memoryFilesExist = { passed: true, count: 0 };
    try {
      const memoryFiles = fs.readdirSync(CONFIG.memoryDir).filter(f => f.endsWith('.md'));
      results.checks.memoryFilesExist.count = memoryFiles.length;
      if (memoryFiles.length === 0) {
        issues.push('No memory files found');
        results.checks.memoryFilesExist.passed = false;
      }
    } catch {
      issues.push('Cannot access memory directory');
      results.checks.memoryFilesExist.passed = false;
    }

    // Update checksums for next validation
    for (const file of CONFIG.criticalFiles) {
      const filePath = path.join(CONFIG.workspaceDir, file);
      if (fs.existsSync(filePath)) {
        this.guardState.criticalFiles[file] = {
          checksum: this.calculateChecksum(filePath),
          size: fs.statSync(filePath).size,
          lastChecked: now(),
        };
      }
    }

    // Determine overall result
    results.passed = issues.length === 0;
    results.issues = issues;

    if (results.passed) {
      this.guardState.checksPassed++;
      log('success', 'All integrity checks passed');
    } else {
      this.guardState.checksFailed++;
      log('error', `Integrity check failed with ${issues.length} issues:`);
      issues.forEach(issue => log('error', `  - ${issue}`));
    }

    this.saveGuardState();
    return results;
  }

  /**
   * Detect context loss indicators
   */
  detectContextLoss() {
    const indicators = [];

    // Indicator 1: Sudden file size decrease
    for (const [file, state] of Object.entries(this.guardState.criticalFiles)) {
      const filePath = path.join(CONFIG.workspaceDir, file);
      if (fs.existsSync(filePath)) {
        const currentSize = fs.statSync(filePath).size;
        const previousSize = state.size || 0;
        
        if (currentSize < previousSize * 0.5) {
          indicators.push({
            type: 'size_decrease',
            file,
            previousSize,
            currentSize,
            severity: 'critical',
          });
        }
      }
    }

    // Indicator 2: Missing recent memory files
    const today = new Date().toISOString().split('T')[0];
    const todayMemoryFile = path.join(CONFIG.memoryDir, `${today}.md`);
    if (!fs.existsSync(todayMemoryFile)) {
      indicators.push({
        type: 'missing_daily_memory',
        file: todayMemoryFile,
        severity: 'warning',
      });
    }

    // Indicator 3: PROJECT-CONTEXT.md not updated recently
    const projectContextPath = path.join(CONFIG.workspaceDir, 'PROJECT-CONTEXT.md');
    if (fs.existsSync(projectContextPath)) {
      const stat = fs.statSync(projectContextPath);
      const age = Date.now() - stat.mtimeMs;
      const ageDays = age / (1000 * 60 * 60 * 24);
      
      if (ageDays > 7) {
        indicators.push({
          type: 'stale_project_context',
          file: 'PROJECT-CONTEXT.md',
          ageDays,
          severity: 'warning',
        });
      }
    }

    if (indicators.length > 0) {
      log('warning', `Detected ${indicators.length} context loss indicators:`);
      indicators.forEach(ind => log('warning', `  - ${ind.type}: ${ind.file} (${ind.severity})`));
    }

    return indicators;
  }

  /**
   * Reconstruct lost context from backups
   */
  reconstruct(targetFile = null) {
    log('info', 'Starting context reconstruction...');

    const recoveries = [];

    // Find most recent valid snapshot
    const snapshots = fs.readdirSync(CONFIG.backupsDir)
      .map(dir => ({
        name: dir,
        path: path.join(CONFIG.backupsDir, dir),
        stat: fs.statSync(path.join(CONFIG.backupsDir, dir)),
      }))
      .sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);

    for (const snapshot of snapshots) {
      const manifestPath = path.join(snapshot.path, 'manifest.json');
      if (!fs.existsSync(manifestPath)) continue;

      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
      
      // If target file specified, only restore that
      const filesToRestore = targetFile 
        ? [targetFile]
        : Object.keys(manifest.files);

      for (const file of filesToRestore) {
        const backupPath = path.join(snapshot.path, file);
        const targetPath = path.join(CONFIG.workspaceDir, file);

        if (fs.existsSync(backupPath)) {
          // Verify backup integrity
          const backupChecksum = this.calculateChecksum(backupPath);
          const expectedChecksum = manifest.files[file]?.checksum;

          if (!expectedChecksum || backupChecksum === expectedChecksum) {
            // Restore file
            fs.copyFileSync(backupPath, targetPath);
            recoveries.push({
              file,
              fromSnapshot: snapshot.name,
              timestamp: manifest.timestamp,
            });
            log('success', `Restored ${file} from snapshot ${snapshot.name}`);
          } else {
            log('error', `Backup checksum mismatch for ${file}`);
          }
        }
      }

      // If we restored everything we needed, stop
      if (recoveries.length >= filesToRestore.length) {
        break;
      }
    }

    if (recoveries.length > 0) {
      this.guardState.recoveries++;
      this.saveGuardState();
      log('success', `Reconstruction complete: ${recoveries.length} files restored`);
    } else {
      log('error', 'Reconstruction failed: no valid backups found');
    }

    return recoveries;
  }

  /**
   * Full protection cycle: snapshot → validate → detect → (reconstruct if needed)
   */
  protect() {
    log('info', '=== Running full protection cycle ===');

    // Step 1: Create snapshot
    const snapshot = this.createSnapshot('pre-validation');

    // Step 2: Validate
    const validation = this.validate();

    // Step 3: Detect context loss
    const indicators = this.detectContextLoss();

    // Step 4: Reconstruct if needed
    let reconstruction = null;
    if (!validation.passed || indicators.some(i => i.severity === 'critical')) {
      log('warning', 'Issues detected, attempting reconstruction...');
      reconstruction = this.reconstruct();
    }

    // Step 5: Post-reconstruction snapshot
    if (reconstruction && reconstruction.length > 0) {
      this.createSnapshot('post-reconstruction');
    }

    const result = {
      timestamp: now(),
      snapshot: snapshot.id,
      validation,
      indicators,
      reconstruction,
      status: validation.passed && indicators.length === 0 ? 'healthy' : 'recovered',
    };

    log('info', `Protection cycle complete: ${result.status}`);
    return result;
  }

  /**
   * Get protection status summary
   */
  getStatus() {
    return {
      initialized: this.guardState.initialized,
      lastCheck: this.guardState.lastCheck,
      checksPassed: this.guardState.checksPassed,
      checksFailed: this.guardState.checksFailed,
      recoveries: this.guardState.recoveries,
      snapshots: fs.existsSync(CONFIG.backupsDir) 
        ? fs.readdirSync(CONFIG.backupsDir).filter(d => d !== '.' && d !== '..').length
        : 0,
    };
  }
}

/**
 * CLI Interface
 */
function main() {
  const guard = new CompactionGuard();
  const command = process.argv[2];
  const arg = process.argv[3];

  switch (command) {
    case 'snapshot':
      const snapshot = guard.createSnapshot(arg || 'manual');
      console.log('\nSnapshot created:');
      console.log(JSON.stringify(snapshot, null, 2));
      break;

    case 'validate':
      const validation = guard.validate();
      console.log('\nValidation Result:');
      console.log(JSON.stringify(validation, null, 2));
      process.exit(validation.passed ? 0 : 1);
      break;

    case 'detect':
      const indicators = guard.detectContextLoss();
      console.log('\nContext Loss Indicators:');
      console.log(JSON.stringify(indicators, null, 2));
      break;

    case 'reconstruct':
      const recoveries = guard.reconstruct(arg);
      console.log('\nReconstruction Result:');
      console.log(JSON.stringify(recoveries, null, 2));
      break;

    case 'protect':
      const result = guard.protect();
      console.log('\nProtection Cycle Result:');
      console.log(JSON.stringify(result, null, 2));
      break;

    case 'status':
      const status = guard.getStatus();
      console.log('\nCompaction Guard Status:');
      console.log(JSON.stringify(status, null, 2));
      break;

    default:
      console.log(`
Compaction Guard - Anti-Context-Loss Protection

Usage:
  node compaction-guard.js snapshot [label]     Create a manual snapshot
  node compaction-guard.js validate             Validate context integrity
  node compaction-guard.js detect               Detect context loss indicators
  node compaction-guard.js reconstruct [file]   Reconstruct from backups
  node compaction-guard.js protect              Run full protection cycle
  node compaction-guard.js status               Show protection status

This tool ensures context is NEVER lost through:
- Multiple redundant backups
- Checksum validation
- Context loss detection
- Automatic reconstruction
`);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { CompactionGuard };
