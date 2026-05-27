#!/usr/bin/env python3
"""Add new files to Xcode project"""

import sys

try:
    from pbxproj import XcodeProject
except ImportError:
    print("Error: pbxproj library not installed")
    print("Install with: pip install pbxproj")
    sys.exit(1)

project_path = "frontend/WavelengthWatch/WavelengthWatch.xcodeproj/project.pbxproj"
project = XcodeProject.load(project_path)

# Add MarkdownContentLoader.swift to Watch App target (source file)
markdown_loader = project.add_file(
    "WavelengthWatch Watch App/Services/MarkdownContentLoader.swift",
    target_name="WavelengthWatch Watch App",
    tree="SOURCE_ROOT",
)

# Add about-content.md to Watch App target as a resource
about_content = project.add_file(
    "WavelengthWatch Watch App/Resources/about-content.md",
    target_name="WavelengthWatch Watch App",
    tree="SOURCE_ROOT",
)

# Add ConceptExplainerViewTests.swift to test target
test_file = project.add_file(
    "WavelengthWatch Watch AppTests/ConceptExplainerViewTests.swift",
    target_name="WavelengthWatch Watch AppTests",
    tree="SOURCE_ROOT",
)

# Save the project
project.save()

print("✅ Successfully added files to Xcode project:")
print("   - MarkdownContentLoader.swift (Watch App target, Services group)")
print("   - about-content.md (Watch App target resources, Resources group)")
print("   - ConceptExplainerViewTests.swift (Test target)")
