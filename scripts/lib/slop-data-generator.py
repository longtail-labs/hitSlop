#!/usr/bin/env python3
"""
Generate realistic test data for Slop templates from JSON schemas.

Usage:
    slop-data-generator.py <schema-file> <variant>

Where variant is:
    1 = Empty/defaults (minimal data, mostly nulls where optional)
    2 = Minimal realistic (some data filled in)
    3 = Full realistic (all fields populated with varied data)
"""

import sys
import json
import random
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

# Smart field name patterns for generating realistic data
FIELD_PATTERNS = {
    "title": [
        "Q2 Product Planning", "Sprint Review", "Budget Overview",
        "Team Meeting Notes", "Project Roadmap", "Client Proposal",
        "Weekly Status Update", "Architecture Review"
    ],
    "name": [
        "Sarah Chen", "Marcus Rodriguez", "Alex Kim", "Jordan Taylor",
        "Sam Patel", "Casey Morgan", "Jamie Liu", "Riley Johnson"
    ],
    "task": [
        "Implement user authentication", "Fix navigation bug",
        "Update documentation", "Review PR #123", "Deploy to staging",
        "Refactor payment flow", "Add error logging", "Optimize database queries"
    ],
    "description": [
        "Complete implementation of core features",
        "Address feedback from code review",
        "Update based on user testing results",
        "Prepare for Q2 launch milestone"
    ],
    "note": [
        "This requires urgent attention",
        "Blocked on API team",
        "Low priority - nice to have",
        "Waiting for design approval"
    ],
    "email": [
        "sarah.chen@example.com", "marcus.r@company.io",
        "alex.kim@startup.co", "jordan@example.org"
    ],
    "category": [
        "Development", "Design", "Marketing", "Operations",
        "Research", "Support", "Sales"
    ],
    "amount": [100, 250, 500, 750, 1000, 1500, 2500],
    "price": [9.99, 19.99, 29.99, 49.99, 99.99, 149.99],
}

# Color palette for variety
COLOR_PALETTE = [
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
    "#DFE6E9", "#74B9FF", "#A29BFE", "#FD79A8", "#FDCB6E",
    "#6C5CE7", "#00B894", "#E17055", "#0984E3", "#D63031"
]

def random_date(days_ago=30, days_ahead=0):
    """Generate random date within range"""
    if days_ahead > 0:
        # Future date
        offset = random.randint(0, days_ahead)
        date = datetime.now() + timedelta(days=offset)
    else:
        # Past date
        offset = random.randint(0, days_ago)
        date = datetime.now() - timedelta(days=offset)
    return date.strftime("%Y-%m-%d")

def random_datetime(days_ago=7):
    """Generate random datetime"""
    offset = random.randint(0, days_ago * 24 * 60)
    dt = datetime.now() - timedelta(minutes=offset)
    return dt.isoformat()

def smart_string_value(field_name: str, field_label: str = "") -> str:
    """Generate realistic string based on field name/label"""
    name_lower = field_name.lower()
    label_lower = field_label.lower()

    # Check patterns
    for pattern, values in FIELD_PATTERNS.items():
        if pattern in name_lower or pattern in label_lower:
            return random.choice(values)

    # Generic fallbacks
    if "url" in name_lower or "link" in name_lower:
        return "https://example.com"
    if "phone" in name_lower:
        return "+1 (555) 123-4567"
    if "address" in name_lower:
        return "123 Main St, San Francisco, CA 94102"
    if "company" in name_lower or "organization" in name_lower:
        return random.choice(["Acme Inc", "StartupCo", "TechCorp", "InnovateLabs"])

    # Default
    return f"Sample {field_label or field_name}"

def smart_number_value(field_name: str, min_val: Optional[float] = None,
                       max_val: Optional[float] = None) -> float:
    """Generate realistic number based on field name and constraints"""
    name_lower = field_name.lower()

    # Apply constraints if present
    if min_val is not None and max_val is not None:
        return round(random.uniform(min_val, max_val), 2)

    # Check patterns
    if "amount" in name_lower or "price" in name_lower or "cost" in name_lower:
        values = FIELD_PATTERNS.get("amount" if "amount" in name_lower else "price", [100])
        return random.choice(values)
    if "percentage" in name_lower or "percent" in name_lower:
        return round(random.uniform(0, 100), 1)
    if "count" in name_lower or "total" in name_lower:
        return random.randint(1, 50)
    if "year" in name_lower:
        return random.randint(2020, 2026)

    # Default
    if min_val is not None:
        return min_val + random.randint(0, 100)
    return random.randint(1, 1000)

class SlopDataGenerator:
    """Generate test data from JSON schema"""

    def __init__(self, schema: Dict[str, Any], variant: int = 2):
        """
        Args:
            schema: JSON schema from `slop schema --json-schema`
            variant: 1=empty, 2=minimal, 3=full
        """
        self.schema = schema
        self.variant = variant
        self.randomness = variant  # More variance in higher variants

    def generate(self) -> Dict[str, Any]:
        """Generate complete data object matching schema"""
        properties = self.schema.get("properties", {})
        required = set(self.schema.get("required", []))

        data = {}
        for field_name, field_def in properties.items():
            # Skip in variant 1 unless required
            if self.variant == 1 and field_name not in required:
                continue

            # 50% chance to skip in variant 2 unless required
            if self.variant == 2 and field_name not in required and random.random() < 0.5:
                continue

            value = self._generate_field(field_name, field_def)
            if value is not None:
                data[field_name] = value

        return data

    def _generate_field(self, field_name: str, field_def: Dict[str, Any]) -> Any:
        """Generate value for a single field"""
        field_type = field_def.get("type")
        title = field_def.get("title", "")

        # Handle nullable
        if field_type == "null":
            return None

        # Handle anyOf (nullable fields)
        if "anyOf" in field_def:
            # Find non-null option
            for option in field_def["anyOf"]:
                if option.get("type") != "null":
                    return self._generate_field(field_name, option)
            return None

        if field_type == "string":
            return self._generate_string(field_name, field_def, title)
        elif field_type == "number" or field_type == "integer":
            return self._generate_number(field_name, field_def)
        elif field_type == "boolean":
            return self._generate_boolean()
        elif field_type == "array":
            return self._generate_array(field_name, field_def)
        elif field_type == "object":
            return self._generate_object(field_name, field_def)

        return None

    def _generate_string(self, field_name: str, field_def: Dict[str, Any],
                        title: str) -> str:
        """Generate string value"""
        # Check for enum
        if "enum" in field_def:
            return random.choice(field_def["enum"])

        # Check for format hints
        format_hint = field_def.get("format", "")

        if format_hint == "date":
            return random_date()
        elif format_hint == "date-time":
            return random_datetime()
        elif format_hint == "color":
            return random.choice(COLOR_PALETTE)
        elif format_hint == "email":
            return random.choice(FIELD_PATTERNS["email"])
        elif format_hint == "uri":
            return "https://example.com"

        # Smart string generation
        return smart_string_value(field_name, title)

    def _generate_number(self, field_name: str, field_def: Dict[str, Any]) -> float:
        """Generate number value"""
        min_val = field_def.get("minimum")
        max_val = field_def.get("maximum")

        value = smart_number_value(field_name, min_val, max_val)

        # Return int if type is integer
        if field_def.get("type") == "integer":
            return int(value)
        return value

    def _generate_boolean(self) -> bool:
        """Generate boolean value"""
        # In variant 1, prefer false (empty state)
        if self.variant == 1:
            return False
        # Otherwise random with slight bias toward true
        return random.random() < 0.6

    def _generate_array(self, field_name: str, field_def: Dict[str, Any]) -> List[Any]:
        """Generate array value"""
        items_def = field_def.get("items", {})
        min_items = field_def.get("minItems", 0)
        max_items = field_def.get("maxItems", 10)

        # Determine count based on variant
        if self.variant == 1:
            count = min_items
        elif self.variant == 2:
            count = min(min_items + random.randint(1, 3), max_items)
        else:  # variant 3
            count = min(random.randint(3, 7), max_items)

        # Generate items
        result = []
        for i in range(count):
            item = self._generate_field(f"{field_name}Item{i}", items_def)
            if item is not None:
                result.append(item)

        return result

    def _generate_object(self, field_name: str, field_def: Dict[str, Any]) -> Dict[str, Any]:
        """Generate object (record) value"""
        properties = field_def.get("properties", {})
        required = set(field_def.get("required", []))

        obj = {}
        for prop_name, prop_def in properties.items():
            # Apply same variant logic recursively
            if self.variant == 1 and prop_name not in required:
                continue
            if self.variant == 2 and prop_name not in required and random.random() < 0.5:
                continue

            value = self._generate_field(prop_name, prop_def)
            if value is not None:
                obj[prop_name] = value

        return obj


def main():
    if len(sys.argv) < 3:
        print("Usage: slop-data-generator.py <schema-file> <variant>", file=sys.stderr)
        print("  variant: 1=empty, 2=minimal, 3=full", file=sys.stderr)
        sys.exit(1)

    schema_file = sys.argv[1]
    variant = int(sys.argv[2])

    # Load schema
    try:
        with open(schema_file, 'r') as f:
            schema = json.load(f)
    except Exception as e:
        print(f"Error loading schema: {e}", file=sys.stderr)
        sys.exit(1)

    # Generate data
    generator = SlopDataGenerator(schema, variant)
    data = generator.generate()

    # Output JSON
    print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
