#!/usr/bin/env node
/**
 * Context Preservation Engine
 * 
 * MISSION: Ensure zero context loss — summarize, contextualize, update, reference after all projects.
 * 
 * This engine runs after EVERY project/mistake/idea and:
 * a) SUMMARIZES: What was done, key decisions, outcomes
 * b) CONTEXTUALIZES: Why it matters, how it connects to other work
 * c) UPDATES: Links to related files, memories, procedures
 * d) REFERENCES: Makes it findable forever
 * 
 * Usage:
 *   node context-preserver.js preserve <project-id>    # Preserve a specific project
 *   node context-preserver.js scan                     # Scan last 12h and preserve
 *   node context-preserver.js validate                 # Validate context integrity
 *   node context-preserver.js search <query>           # Search all context
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const CONFIG = {
  workspaceDir: process.env.HENRY_WORKSPACE || path.join(process.env.HOME, '.openclaw/workspace'),
  memoryDir: process.env.HENRY_MEMORY || path.join(process.env.HOME, '.openclaw/memory'),
  scriptsDir: process.env.HENRY_SCRIPTS || path.join(process.env.HOME, '.openclaw/scripts'),
  stateFile: path.join(process.env.HOME, '.openclaw/mission-control/state.json'),
  projectContextFile: path.join(process.env.HOME, '.openclaw/workspace/PROJECT-CONTEXT.md'),
  workspaceMemoryFile: path.join(process.env.HOME, '.openclaw/workspace/WORKSPACE-MEMORY.md'),
  compactionGuardFile: path.join(process.env.HOME, '.openclaw/.compaction-guard.json'),
  backupsDir: path.join(process.env.HOME, '.openclaw/.context-backups'),
};

// Ensure directories exist
[CONFIG.memoryDir, CONFIG.scriptsDir, CONFIG.backupsDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Utility functions
const now = () => new Date().toISOString();
const today = () => new Date().toISOString().split('T')[0];
const log = (level, message) => {
  const timestamp = now();
  const entry = `[${timestamp}] [${level.toUpperCase()}] ${message}`;
  console.log(entry);
  
  // Also log to daily log file
  const logFile = path.join(CONFIG.memoryDir, `${today()}.log`);
  fs.appendFileSync(logFile, entry + '\n');
};

/**
 * Context Entry Structure
 */
class ContextEntry {
  constructor(data = {}) {
    this.id = data.id || `ctx-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    this.timestamp = data.timestamp || now();
    this.type = data.type || 'general'; // project, mistake, idea, decision, learning
    this.title = data.title || 'Untitled';
    this.summary = data.summary || '';
    this.context = data.context || ''; // Why it matters
    this.decisions = data.decisions || [];
    this.outcomes = data.outcomes || [];
    this.learnings = data.learnings || [];
    this.relatedFiles = data.relatedFiles || [];
    this.relatedMemories = data.relatedMemories || [];
    this.relatedProjects = data.relatedProjects || [];
    this.tags = data.tags || [];
    this.importance = data.importance || 'medium'; // critical, high, medium, low
    this.searchKeywords = data.searchKeywords || [];
  }

  toMarkdown() {
    return `### ${this.title}

**ID:** \`${this.id}\`  
**Type:** ${this.type}  
**Importance:** ${this.importance}  
**Timestamp:** ${this.timestamp}

#### Summary
${this.summary}

#### Context (Why It Matters)
${this.context}

#### Key Decisions
${this.decisions.map(d => `- ${d}`).join('\n') || '- None recorded'}

#### Outcomes
${this.outcomes.map(o => `- ${o}`).join('\n') || '- None recorded'}

#### Learnings
${this.learnings.map(l => `- ${l}`).join('\n') || '- None recorded'}

#### Related Files
${this.relatedFiles.map(f => `- [${path.basename(f)}](${f})`).join('\n') || '- None'}

#### Related Memories
${this.relatedMemories.map(m => `- ${m}`).join('\n') || '- None'}

#### Tags
${this.tags.map(t => `#${t}`).join(' ')}

---
`;
  }

  toJSON() {
    return {
      id: this.id,
      timestamp: this.timestamp,
      type: this.type,
      title: this.title,
      summary: this.summary,
      context: this.context,
      decisions: this.decisions,
      outcomes: this.outcomes,
      learnings: this.learnings,
      relatedFiles: this.relatedFiles,
      relatedMemories: this.relatedMemories,
      relatedProjects: this.relatedProjects,
      tags: this.tags,
      importance: this.importance,
      searchKeywords: this.searchKeywords,
    };
  }

  toJSONString() {
    return JSON.stringify(this.toJSON(), null, 2);
  }
}

/**
 * Context Preservation Engine
 */
class ContextPreserver {
  constructor() {
    this.entries = [];
    this.loadExistingContext();
  }

  loadExistingContext() {
    // Load from PROJECT-CONTEXT.md if exists
    if (fs.existsSync(CONFIG.projectContextFile)) {
      log('info', `Loading existing project context from ${CONFIG.projectContextFile}`);
    }
  }

  /**
   * SUMMARIZE: Extract what was done, key decisions, outcomes
   */
  summarize(projectPath, options = {}) {
    log('info', `Summarizing project: ${projectPath}`);

    const entry = new ContextEntry({
      type: options.type || 'project',
      title: options.title || path.basename(projectPath),
      summary: options.summary || this.generateSummary(projectPath),
      decisions: options.decisions || [],
      outcomes: options.outcomes || [],
      learnings: options.learnings || [],
      relatedFiles: options.relatedFiles || this.findRelatedFiles(projectPath),
      tags: options.tags || [],
      importance: options.importance || 'medium',
    });

    this.entries.push(entry);
    return entry;
  }

  /**
   * CONTEXTUALIZE: Explain why it matters and how it connects
   */
  contextualize(entryId, context) {
    const entry = this.entries.find(e => e.id === entryId);
    if (entry) {
      entry.context = context;
      entry.relatedProjects = this.findRelatedProjects(entry);
      entry.relatedMemories = this.findRelatedMemories(entry);
      log('info', `Contextualized entry: ${entryId}`);
    }
    return entry;
  }

  /**
   * UPDATE: Link to related files, memories, procedures
   */
  update(entryId, updates) {
    const entry = this.entries.find(e => e.id === entryId);
    if (entry) {
      Object.assign(entry, updates);
      log('info', `Updated entry: ${entryId}`);
    }
    return entry;
  }

  /**
   * REFERENCE: Make it findable forever
   */
  reference(entry) {
    // 1. Write to daily memory file
    this.writeToDailyFile(entry);

    // 2. Append to WORKSPACE-MEMORY.md
    this.appendToWorkspaceMemory(entry);

    // 3. Update PROJECT-CONTEXT.md
    this.updateProjectContext(entry);

    // 4. Update search index
    this.updateSearchIndex(entry);

    // 5. Create backup
    this.createBackup(entry);

    log('info', `Referenced entry: ${entry.id}`);
    return entry;
  }

  /**
   * Full preservation pipeline: SUMMARIZE → CONTEXTUALIZE → UPDATE → REFERENCE
   */
  preserve(projectPath, options = {}) {
    log('info', `Starting full preservation for: ${projectPath}`);

    // Step 1: SUMMARIZE
    const entry = this.summarize(projectPath, options);

    // Step 2: CONTEXTUALIZE
    if (options.context) {
      this.contextualize(entry.id, options.context);
    }

    // Step 3: UPDATE
    if (options.updates) {
      this.update(entry.id, options.updates);
    }

    // Step 4: REFERENCE
    this.reference(entry);

    log('success', `Preservation complete: ${entry.id}`);
    return entry;
  }

  /**
   * Scan last 12 hours and preserve any new work
   */
  scan(hours = 12) {
    log('info', `Scanning last ${hours} hours for work to preserve...`);

    const since = new Date(Date.now() - hours * 60 * 60 * 1000);
    const findings = [];

    // Scan workspace for recently modified files
    try {
      const files = execSync(
        `find "${CONFIG.workspaceDir}" -type f -mtime -${hours / 24} -not -path "*/node_modules/*" -not -path "*/.git/*"`,
        { encoding: 'utf-8' }
      ).trim().split('\n').filter(Boolean);

      log('info', `Found ${files.length} recently modified files`);

      // Group files by project/directory
      const projectGroups = this.groupFilesByProject(files);

      for (const [projectPath, projectFiles] of Object.entries(projectGroups)) {
        const entry = this.preserve(projectPath, {
          type: 'auto-scan',
          title: `Auto-detected: ${path.basename(projectPath)}`,
          summary: `Found ${projectFiles.length} modified files in last ${hours} hours`,
          relatedFiles: projectFiles,
          tags: ['auto-scanned', 'unpreserved-work'],
          importance: 'medium',
        });
        findings.push(entry);
      }
    } catch (err) {
      log('error', `Scan failed: ${err.message}`);
    }

    log('success', `Scan complete. Preserved ${findings.length} projects.`);
    return findings;
  }

  /**
   * Validate context integrity (anti-compaction protection)
   */
  validate() {
    log('info', 'Validating context integrity...');

    const issues = [];
    const checks = [
      { name: 'Daily memory file exists', test: () => fs.existsSync(path.join(CONFIG.memoryDir, `${today()}.md`)) },
      { name: 'PROJECT-CONTEXT.md exists', test: () => fs.existsSync(CONFIG.projectContextFile) },
      { name: 'WORKSPACE-MEMORY.md exists', test: () => fs.existsSync(CONFIG.workspaceMemoryFile) },
      { name: 'Backups directory exists', test: () => fs.existsSync(CONFIG.backupsDir) },
      { name: 'State file exists', test: () => fs.existsSync(CONFIG.stateFile) },
    ];

    for (const check of checks) {
      const passed = check.test();
      if (!passed) {
        issues.push(check.name);
        log('warning', `Failed: ${check.name}`);
      } else {
        log('success', `Passed: ${check.name}`);
      }
    }

    // Check for context loss indicators
    const recentBackups = this.getRecentBackups(7);
    if (recentBackups.length < 3) {
      issues.push('Insufficient recent backups');
      log('warning', 'Less than 3 backups in last 7 days');
    }

    // Write validation result
    const validationResult = {
      timestamp: now(),
      passed: issues.length === 0,
      issues,
      checks: checks.length,
      backups: recentBackups.length,
    };

    fs.writeFileSync(CONFIG.compactionGuardFile, JSON.stringify(validationResult, null, 2));

    if (issues.length > 0) {
      log('error', `Validation failed with ${issues.length} issues`);
    } else {
      log('success', 'All context integrity checks passed');
    }

    return validationResult;
  }

  /**
   * Search all context
   */
  search(query) {
    log('info', `Searching for: ${query}`);

    const results = [];
    const lowerQuery = query.toLowerCase();

    // Search entries
    for (const entry of this.entries) {
      const searchable = [
        entry.title,
        entry.summary,
        entry.context,
        ...entry.tags,
        ...entry.searchKeywords,
      ].join(' ').toLowerCase();

      if (searchable.includes(lowerQuery)) {
        results.push({
          type: 'entry',
          id: entry.id,
          title: entry.title,
          relevance: this.calculateRelevance(searchable, lowerQuery),
        });
      }
    }

    // Search files
    try {
      const files = execSync(
        `grep -r -l "${query}" "${CONFIG.memoryDir}" "${CONFIG.workspaceDir}" --include="*.md" 2>/dev/null || true`,
        { encoding: 'utf-8' }
      ).trim().split('\n').filter(Boolean);

      for (const file of files) {
        results.push({
          type: 'file',
          path: file,
          title: path.basename(file),
          relevance: 1,
        });
      }
    } catch (err) {
      // Grep might fail if no matches, that's ok
    }

    results.sort((a, b) => b.relevance - a.relevance);
    log('success', `Found ${results.length} results`);

    return results;
  }

  // Helper methods
  generateSummary(projectPath) {
    try {
      const gitLog = execSync(
        `cd "${projectPath}" && git log --oneline -10 2>/dev/null || echo "No git history"`,
        { encoding: 'utf-8' }
      );
      return `Recent activity:\n${gitLog}`;
    } catch {
      return `Project at ${projectPath}`;
    }
  }

  findRelatedFiles(projectPath) {
    try {
      return execSync(
        `find "${projectPath}" -type f -mtime -7 -not -path "*/node_modules/*" -not -path "*/.git/*" | head -20`,
        { encoding: 'utf-8' }
      ).trim().split('\n').filter(Boolean);
    } catch {
      return [];
    }
  }

  findRelatedProjects(entry) {
    // Find projects with similar tags or files
    return [];
  }

  findRelatedMemories(entry) {
    // Find memories with similar tags
    return [];
  }

  groupFilesByProject(files) {
    const groups = {};
    for (const file of files) {
      const projectPath = path.dirname(file);
      if (!groups[projectPath]) {
        groups[projectPath] = [];
      }
      groups[projectPath].push(file);
    }
    return groups;
  }

  writeToDailyFile(entry) {
    const dailyFile = path.join(CONFIG.memoryDir, `${today()}.md`);
    const header = `## Context Preservation Log - ${today()}\n\n`;
    
    let content = '';
    if (!fs.existsSync(dailyFile)) {
      content = `# Daily Context Log - ${today()}\n\n${header}`;
    }
    content += entry.toMarkdown();

    fs.appendFileSync(dailyFile, content);
    log('info', `Written to daily file: ${dailyFile}`);
  }

  appendToWorkspaceMemory(entry) {
    const header = `## ${entry.title} [${entry.timestamp}]\n\n`;
    const content = header + entry.toMarkdown();

    fs.appendFileSync(CONFIG.workspaceMemoryFile, content);
    log('info', `Appended to WORKSPACE-MEMORY.md`);
  }

  updateProjectContext(entry) {
    let content = '';
    if (fs.existsSync(CONFIG.projectContextFile)) {
      content = fs.readFileSync(CONFIG.projectContextFile, 'utf-8');
    } else {
      content = `# PROJECT-CONTEXT.md\n\nLiving document of all active and completed projects.\n\n`;
      content += `> This file is auto-updated by the Context Preservation Engine.\n`;
      content += `> Last updated: ${now()}\n\n`;
    }

    // Add new entry
    content += entry.toMarkdown();

    fs.writeFileSync(CONFIG.projectContextFile, content);
    log('info', `Updated PROJECT-CONTEXT.md`);
  }

  updateSearchIndex(entry) {
    // Create/update a JSON search index
    const indexFile = path.join(CONFIG.memoryDir, 'search-index.json');
    let index = [];
    
    if (fs.existsSync(indexFile)) {
      index = JSON.parse(fs.readFileSync(indexFile, 'utf-8'));
    }

    index.push({
      id: entry.id,
      title: entry.title,
      type: entry.type,
      tags: entry.tags,
      timestamp: entry.timestamp,
      keywords: entry.searchKeywords,
    });

    fs.writeFileSync(indexFile, JSON.stringify(index, null, 2));
  }

  createBackup(entry) {
    const backupFile = path.join(CONFIG.backupsDir, `${entry.id}.json`);
    fs.writeFileSync(backupFile, entry.toJSONString());
    log('info', `Created backup: ${backupFile}`);
  }

  getRecentBackups(days) {
    try {
      const files = fs.readdirSync(CONFIG.backupsDir);
      const since = Date.now() - days * 24 * 60 * 60 * 1000;
      
      return files.filter(file => {
        const stat = fs.statSync(path.join(CONFIG.backupsDir, file));
        return stat.mtimeMs > since;
      });
    } catch {
      return [];
    }
  }

  calculateRelevance(text, query) {
    const occurrences = (text.match(new RegExp(query, 'g')) || []).length;
    return occurrences;
  }
}

/**
 * CLI Interface
 */
function main() {
  const preserver = new ContextPreserver();
  const command = process.argv[2];
  const arg = process.argv[3];

  switch (command) {
    case 'preserve':
      if (!arg) {
        console.error('Usage: node context-preserver.js preserve <project-path>');
        process.exit(1);
      }
      preserver.preserve(arg, {
        title: process.argv[4] || path.basename(arg),
        summary: process.argv[5] || '',
      });
      break;

    case 'scan':
      const hours = parseInt(arg) || 12;
      preserver.scan(hours);
      break;

    case 'validate':
      const result = preserver.validate();
      console.log('\nValidation Result:');
      console.log(JSON.stringify(result, null, 2));
      process.exit(result.passed ? 0 : 1);
      break;

    case 'search':
      if (!arg) {
        console.error('Usage: node context-preserver.js search <query>');
        process.exit(1);
      }
      const results = preserver.search(arg);
      console.log('\nSearch Results:');
      results.forEach(r => console.log(`- [${r.type}] ${r.title} (relevance: ${r.relevance})`));
      break;

    default:
      console.log(`
Context Preservation Engine

Usage:
  node context-preserver.js preserve <project-path> [title] [summary]
  node context-preserver.js scan [hours=12]
  node context-preserver.js validate
  node context-preserver.js search <query>

Environment Variables:
  HENRY_WORKSPACE    Workspace directory (default: ~/.openclaw/workspace)
  HENRY_MEMORY       Memory directory (default: ~/.openclaw/memory)
  HENRY_SCRIPTS      Scripts directory (default: ~/.openclaw/scripts)
`);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { ContextPreserver, ContextEntry };
