#!/usr/bin/env python
"""
Design Creator Utility for DTU Tufting System
أداة لإنشاء تصاميم جديدة للنظام
"""

import json
import os
from pathlib import Path

EXAMPLES_DIR = 'examples'

def create_design_interactive():
    """Create a design interactively"""
    print("\n" + "="*60)
    print("🎨 Create New Tufting Design")
    print("="*60 + "\n")
    
    # Get design name
    name = input("📝 Design Name: ").strip()
    if not name:
        print("❌ Design name cannot be empty")
        return False
    
    description = input("📋 Description (optional): ").strip()
    
    # Get tuft points
    print("\n📍 Enter tuft points (x, y)")
    print("   Example: 100 100")
    print("   Type 'done' when finished\n")
    
    tufts = []
    point_num = 1
    while True:
        try:
            user_input = input(f"Point {point_num}: ").strip()
            
            if user_input.lower() == 'done':
                if not tufts:
                    print("❌ At least one point is required")
                    continue
                break
            
            parts = user_input.split()
            if len(parts) != 2:
                print("   ❌ Invalid format. Use: x y")
                continue
            
            x, y = float(parts[0]), float(parts[1])
            tufts.append({"x": x, "y": y})
            point_num += 1
            
        except ValueError:
            print("   ❌ Invalid numbers")
            continue
    
    # Create design object
    design = {
        "name": name,
        "description": description,
        "tufts": tufts
    }
    
    # Generate filename
    filename = name.lower().replace(" ", "_") + "_design.json"
    filepath = os.path.join(EXAMPLES_DIR, filename)
    
    # Check if file exists
    if os.path.exists(filepath):
        overwrite = input(f"\n⚠️  File '{filename}' already exists. Overwrite? (y/n): ").lower()
        if overwrite != 'y':
            print("❌ Cancelled")
            return False
    
    # Save design
    try:
        os.makedirs(EXAMPLES_DIR, exist_ok=True)
        with open(filepath, 'w') as f:
            json.dump(design, f, indent=2)
        
        print(f"\n✅ Design saved: {filepath}")
        print(f"   Name: {name}")
        print(f"   Points: {len(tufts)}")
        print(f"   Bounds: X({min(t['x'] for t in tufts):.1f}-{max(t['x'] for t in tufts):.1f}), " +
              f"Y({min(t['y'] for t in tufts):.1f}-{max(t['y'] for t in tufts):.1f})")
        return True
        
    except Exception as e:
        print(f"❌ Error saving design: {e}")
        return False

def create_grid_design():
    """Create a grid pattern design"""
    print("\n" + "="*60)
    print("🔲 Create Grid Pattern Design")
    print("="*60 + "\n")
    
    try:
        start_x = float(input("Start X (mm): "))
        start_y = float(input("Start Y (mm): "))
        spacing = float(input("Spacing between points (mm): "))
        rows = int(input("Number of rows: "))
        cols = int(input("Number of columns: "))
        
        name = input("Design name: ").strip()
        if not name:
            name = f"grid_{rows}x{cols}"
        
        # Generate grid
        tufts = []
        for row in range(rows):
            for col in range(cols):
                x = start_x + col * spacing
                y = start_y + row * spacing
                tufts.append({"x": x, "y": y})
        
        # Create design
        design = {
            "name": name,
            "description": f"Grid pattern: {rows}x{cols} ({len(tufts)} points)",
            "tufts": tufts
        }
        
        # Save
        filename = name.lower().replace(" ", "_") + "_design.json"
        filepath = os.path.join(EXAMPLES_DIR, filename)
        
        os.makedirs(EXAMPLES_DIR, exist_ok=True)
        with open(filepath, 'w') as f:
            json.dump(design, f, indent=2)
        
        print(f"\n✅ Grid design created: {filename}")
        print(f"   Size: {rows}x{cols} ({len(tufts)} points)")
        print(f"   Spacing: {spacing} mm")
        return True
        
    except ValueError as e:
        print(f"❌ Invalid input: {e}")
        return False

def create_circle_design():
    """Create a circular pattern design"""
    print("\n" + "="*60)
    print("⭕ Create Circle Pattern Design")
    print("="*60 + "\n")
    
    try:
        center_x = float(input("Circle center X (mm): "))
        center_y = float(input("Circle center Y (mm): "))
        radius = float(input("Radius (mm): "))
        num_points = int(input("Number of points: "))
        
        name = input("Design name: ").strip()
        if not name:
            name = f"circle_{num_points}"
        
        # Generate circle
        import math
        tufts = []
        for i in range(num_points):
            angle = 2 * math.pi * i / num_points
            x = center_x + radius * math.cos(angle)
            y = center_y + radius * math.sin(angle)
            tufts.append({"x": x, "y": y})
        
        # Create design
        design = {
            "name": name,
            "description": f"Circle pattern: {num_points} points, radius {radius} mm",
            "tufts": tufts
        }
        
        # Save
        filename = name.lower().replace(" ", "_") + "_design.json"
        filepath = os.path.join(EXAMPLES_DIR, filename)
        
        os.makedirs(EXAMPLES_DIR, exist_ok=True)
        with open(filepath, 'w') as f:
            json.dump(design, f, indent=2)
        
        print(f"\n✅ Circle design created: {filename}")
        print(f"   Points: {num_points}")
        print(f"   Radius: {radius} mm")
        return True
        
    except ValueError as e:
        print(f"❌ Invalid input: {e}")
        return False

def list_designs():
    """List all available designs"""
    print("\n" + "="*60)
    print("📂 Available Designs")
    print("="*60 + "\n")
    
    if not os.path.exists(EXAMPLES_DIR):
        print("❌ No designs directory found")
        return
    
    designs = [f for f in os.listdir(EXAMPLES_DIR) if f.endswith('.json')]
    
    if not designs:
        print("No designs found")
        return
    
    for i, design_file in enumerate(designs, 1):
        filepath = os.path.join(EXAMPLES_DIR, design_file)
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
                points = len(data.get('tufts', []))
                desc = data.get('description', 'No description')
                print(f"{i}. {design_file}")
                print(f"   → {desc}")
                print(f"   → Points: {points}")
        except:
            pass
    print()

def main():
    while True:
        print("\n" + "="*60)
        print("🎯 DTU Tufting System - Design Creator")
        print("="*60)
        print("\n1. Create Design Manually")
        print("2. Create Grid Pattern")
        print("3. Create Circle Pattern")
        print("4. List Available Designs")
        print("5. Exit\n")
        
        choice = input("Select option (1-5): ").strip()
        
        if choice == '1':
            create_design_interactive()
        elif choice == '2':
            create_grid_design()
        elif choice == '3':
            create_circle_design()
        elif choice == '4':
            list_designs()
        elif choice == '5':
            print("\n👋 Goodbye!")
            break
        else:
            print("❌ Invalid choice")

if __name__ == '__main__':
    main()
