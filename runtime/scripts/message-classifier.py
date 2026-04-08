#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════════
# Henry Message Processor — Python Classifier Module
# Uses local LLM via Ollama for privacy-preserving message classification
# ═══════════════════════════════════════════════════════════════════════════════

import sys
import json
import re
import subprocess
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
from enum import Enum

class MessageType(Enum):
    BILL = "bill"
    APPOINTMENT = "appointment"
    DEADLINE = "deadline"
    SOCIAL = "social"
    WORK = "work"
    SPAM = "spam"
    FYI = "fyi"
    UNKNOWN = "unknown"

class Priority(Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

@dataclass
class Classification:
    category: MessageType
    confidence: float
    details: Dict[str, Any]
    action: str

@dataclass
class MessageAnalysis:
    categories: List[Classification]
    priority: Priority
    summary: str
    extracted_dates: List[str]
    extracted_amounts: List[str]
    extracted_entities: List[str]

class MessageClassifier:
    """Local LLM-based message classifier using Ollama"""
    
    def __init__(self, model: str = "gemma3:1b"):
        self.model = model
        self._check_ollama()
    
    def _check_ollama(self):
        """Verify Ollama is available"""
        try:
            subprocess.run(["ollama", "list"], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            raise RuntimeError("Ollama not found. Please install Ollama and pull a model.")
    
    def _run_ollama(self, prompt: str) -> str:
        """Run Ollama with the given prompt"""
        try:
            result = subprocess.run(
                ["ollama", "run", self.model, "--format", "json"],
                input=prompt,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            return '{"error": "timeout"}'
        except Exception as e:
            return json.dumps({"error": str(e)})
    
    def _build_classification_prompt(self, subject: str, sender: str, content: str) -> str:
        """Build the classification prompt"""
        # Truncate content if too long
        content = content[:1500] if len(content) > 1500 else content
        
        prompt = f"""You are a message classifier. Analyze this message and classify it.

CLASSIFICATION CATEGORIES:
1. BILL - Payment due, invoice, bill notification, payment confirmation, subscription renewal
2. APPOINTMENT - Meeting scheduled, calendar invite, appointment confirmation, reservation, booking
3. DEADLINE - Due date, task deadline, project milestone, expiration date, submission deadline
4. SOCIAL - Personal message from family/friend, social invitation, casual conversation
5. WORK - Work-related communication, project updates, client messages, professional correspondence
6. SPAM - Unwanted marketing, promotional emails, newsletters, unsolicited offers
7. FYI - Informational only, no action needed, general updates

EXTRACT:
- Dates (in YYYY-MM-DD format if possible)
- Monetary amounts (with currency)
- Key people/organizations
- Locations
- Action items

Respond in this exact JSON format:
{{
  "categories": [
    {{"name": "CATEGORY_NAME", "confidence": 0.0-1.0, "details": {{}}, "action": "description"}}
  ],
  "priority": "high|medium|low",
  "summary": "One sentence summary",
  "dates": ["YYYY-MM-DD"],
  "amounts": ["$0.00"],
  "entities": ["names"]
}}

MESSAGE TO CLASSIFY:
Subject: {subject}
From: {sender}
Content: {content}

JSON RESPONSE:"""
        return prompt
    
    def classify(self, subject: str, sender: str, content: str) -> MessageAnalysis:
        """Classify a message and return structured analysis"""
        
        prompt = self._build_classification_prompt(subject, sender, content)
        response = self._run_ollama(prompt)
        
        # Try to parse JSON response
        try:
            data = json.loads(response)
        except json.JSONDecodeError:
            # Try to extract JSON from text
            json_match = re.search(r'\{.*\}', response, re.DOTALL)
            if json_match:
                try:
                    data = json.loads(json_match.group())
                except:
                    data = self._fallback_classification(subject, sender, content)
            else:
                data = self._fallback_classification(subject, sender, content)
        
        # Parse categories
        categories = []
        for cat_data in data.get("categories", []):
            try:
                cat_type = MessageType(cat_data.get("name", "unknown").lower())
            except ValueError:
                cat_type = MessageType.UNKNOWN
            
            categories.append(Classification(
                category=cat_type,
                confidence=float(cat_data.get("confidence", 0.5)),
                details=cat_data.get("details", {}),
                action=cat_data.get("action", "Review message")
            ))
        
        # Determine priority
        try:
            priority = Priority(data.get("priority", "low"))
        except ValueError:
            priority = Priority.LOW
        
        return MessageAnalysis(
            categories=categories,
            priority=priority,
            summary=data.get("summary", "No summary available"),
            extracted_dates=data.get("dates", []),
            extracted_amounts=data.get("amounts", []),
            extracted_entities=data.get("entities", [])
        )
    
    def _fallback_classification(self, subject: str, sender: str, content: str) -> Dict:
        """Rule-based fallback classification when LLM fails"""
        text = f"{subject} {content}".lower()
        
        categories = []
        
        # Bill detection
        bill_keywords = ['invoice', 'bill', 'payment due', 'amount due', 'subscription', 'charged', 'receipt', 'payment confirmation']
        if any(kw in text for kw in bill_keywords):
            categories.append({
                "name": "bill",
                "confidence": 0.85,
                "details": {},
                "action": "Add to Finnova and calendar"
            })
        
        # Appointment detection
        appt_keywords = ['appointment', 'meeting', 'scheduled', 'calendar invite', 'booking', 'reservation', 'interview']
        if any(kw in text for kw in appt_keywords):
            categories.append({
                "name": "appointment",
                "confidence": 0.80,
                "details": {},
                "action": "Add to calendar"
            })
        
        # Deadline detection
        deadline_keywords = ['deadline', 'due date', 'due by', 'expires', 'submission', 'milestone', 'due on']
        if any(kw in text for kw in deadline_keywords):
            categories.append({
                "name": "deadline",
                "confidence": 0.80,
                "details": {},
                "action": "Create task in Mission Control"
            })
        
        # Extract dates
        dates = self._extract_dates(text)
        amounts = self._extract_amounts(text)
        
        return {
            "categories": categories if categories else [{"name": "fyi", "confidence": 0.6, "details": {}, "action": "No action needed"}],
            "priority": "medium" if categories else "low",
            "summary": f"Message from {sender}: {subject[:50]}",
            "dates": dates,
            "amounts": amounts,
            "entities": []
        }
    
    def _extract_dates(self, text: str) -> List[str]:
        """Extract dates from text using regex patterns"""
        dates = []
        
        # ISO format: 2024-01-15
        iso_pattern = r'\b(20\d{2})-(\d{1,2})-(\d{1,2})\b'
        for match in re.finditer(iso_pattern, text):
            dates.append(f"{match.group(1)}-{match.group(2).zfill(2)}-{match.group(3).zfill(2)}")
        
        # US format: 01/15/2024 or 1/15/24
        us_pattern = r'\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b'
        for match in re.finditer(us_pattern, text):
            month, day, year = match.groups()
            if len(year) == 2:
                year = f"20{year}"
            dates.append(f"{year}-{month.zfill(2)}-{day.zfill(2)}")
        
        return dates[:5]  # Limit to 5 dates
    
    def _extract_amounts(self, text: str) -> List[str]:
        """Extract monetary amounts from text"""
        amounts = []
        
        # Currency patterns
        patterns = [
            r'\$[\d,]+\.?\d*',  # $100, $1,000.50
            r'\b\d+\.\d{2}\b',  # 100.50
            r'\bAUD\s+[\d,]+',  # AUD 100
            r'\bUSD\s+[\d,]+',  # USD 100
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, text)
            amounts.extend(matches)
        
        return amounts[:3]  # Limit to 3 amounts


def main():
    """CLI interface for the classifier"""
    if len(sys.argv) < 2:
        print("Usage: message-classifier.py <command> [args]", file=sys.stderr)
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "classify":
        # Read message from stdin
        message_data = json.load(sys.stdin)
        
        classifier = MessageClassifier(model=os.environ.get("OLLAMA_MODEL", "gemma3:1b"))
        
        analysis = classifier.classify(
            subject=message_data.get("subject", ""),
            sender=message_data.get("sender", ""),
            content=message_data.get("content", "")
        )
        
        # Convert to JSON-serializable dict
        result = {
            "categories": [
                {
                    "name": c.category.value,
                    "confidence": c.confidence,
                    "details": c.details,
                    "action": c.action
                }
                for c in analysis.categories
            ],
            "priority": analysis.priority.value,
            "summary": analysis.summary,
            "dates": analysis.extracted_dates,
            "amounts": analysis.extracted_amounts,
            "entities": analysis.extracted_entities
        }
        
        print(json.dumps(result, indent=2))
    
    elif command == "test":
        # Run test classification
        classifier = MessageClassifier()
        
        test_messages = [
            {
                "subject": "Your electricity bill is due",
                "sender": "energy@utility.com",
                "content": "Your bill of $150.50 is due on 2024-01-15. Please pay by the due date to avoid late fees."
            },
            {
                "subject": "Meeting: Project Review",
                "sender": "boss@company.com", 
                "content": "Let's meet tomorrow at 2pm to review the Q4 project status."
            },
            {
                "subject": "Tax return deadline approaching",
                "sender": "ato.gov.au",
                "content": "Your tax return is due by October 31, 2024."
            }
        ]
        
        for msg in test_messages:
            print(f"\n{'='*60}")
            print(f"Subject: {msg['subject']}")
            print(f"From: {msg['sender']}")
            print(f"Content: {msg['content'][:100]}...")
            print("-"*60)
            
            analysis = classifier.classify(msg["subject"], msg["sender"], msg["content"])
            
            print(f"Summary: {analysis.summary}")
            print(f"Priority: {analysis.priority.value}")
            print("Categories:")
            for cat in analysis.categories:
                print(f"  - {cat.category.value} (confidence: {cat.confidence:.2f})")
                print(f"    Action: {cat.action}")
            if analysis.extracted_dates:
                print(f"Dates found: {', '.join(analysis.extracted_dates)}")
            if analysis.extracted_amounts:
                print(f"Amounts found: {', '.join(analysis.extracted_amounts)}")
    
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    import os
    main()
