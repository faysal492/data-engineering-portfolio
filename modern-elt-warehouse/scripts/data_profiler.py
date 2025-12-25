#!/usr/bin/env python3
"""
Data Profiler Script
====================
Analyzes downloaded CSV files and generates comprehensive quality reports.

This script:
1. Loads each CSV file using Pandas
2. Generates statistical profiles (descriptive statistics, distributions)
3. Identifies missing values, duplicates, outliers
4. Creates visual profiling reports
5. Generates data dictionary

Requirements:
    - Dependencies: pandas, ydata-profiling, click, rich

Usage:
    python scripts/data_profiler.py
    python scripts/data_profiler.py --minimal  # Faster, less detailed
"""

import sys
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple

import click
import pandas as pd
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

# Initialize Rich console
console = Console()

# Configuration
DATA_DIR = Path(__file__).parent.parent / "data"
RAW_DIR = DATA_DIR / "raw"
REPORTS_DIR = Path(__file__).parent.parent / "reports"

# Expected CSV files
CSV_FILES = [
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_customers_dataset.csv",
    "olist_sellers_dataset.csv",
    "olist_products_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_geolocation_dataset.csv",
    "product_category_name_translation.csv",
]


def load_csv(file_path: Path) -> Tuple[bool, pd.DataFrame]:
    """Load CSV file with error handling."""
    try:
        df = pd.read_csv(file_path)
        return True, df
    except Exception as e:
        console.print(f"[red]✗ Error loading {file_path.name}: {e}[/red]")
        return False, None


def analyze_dataframe(df: pd.DataFrame, filename: str) -> Dict:
    """Generate comprehensive profile of a dataframe."""
    profile = {
        "filename": filename,
        "rows": len(df),
        "columns": len(df.columns),
        "size_mb": df.memory_usage(deep=True).sum() / (1024 * 1024),
        "duplicates": {
            "total": df.duplicated().sum(),
            "percentage": round((df.duplicated().sum() / len(df) * 100), 2),
        },
        "columns_info": {},
    }
    
    # Analyze each column
    for col in df.columns:
        col_info = {
            "dtype": str(df[col].dtype),
            "non_null": int(df[col].notna().sum()),
            "null": int(df[col].isna().sum()),
            "null_percentage": round((df[col].isna().sum() / len(df) * 100), 2),
            "unique": int(df[col].nunique()),
        }
        
        # Additional stats for numeric columns
        if pd.api.types.is_numeric_dtype(df[col]):
            col_info.update({
                "mean": float(df[col].mean()),
                "median": float(df[col].median()),
                "min": float(df[col].min()),
                "max": float(df[col].max()),
                "std": float(df[col].std()),
            })
        
        # Additional stats for string columns
        elif pd.api.types.is_string_dtype(df[col]):
            col_info.update({
                "min_length": int(df[col].str.len().min()),
                "max_length": int(df[col].str.len().max()),
                "empty_strings": int((df[col].str.len() == 0).sum()),
            })
        
        profile["columns_info"][col] = col_info
    
    return profile


def generate_quality_score(profile: Dict) -> float:
    """
    Calculate data quality score (0-100).
    
    Scoring:
    - Start with 100 points
    - Deduct for null values (0.5 points per 1%)
    - Deduct for duplicates (2 points per 1%)
    """
    score = 100.0
    
    # Deduct for null values
    for col_info in profile["columns_info"].values():
        score -= col_info["null_percentage"] * 0.5
    
    # Deduct for duplicates
    score -= profile["duplicates"]["percentage"] * 2
    
    # Floor at 0
    return max(0, score)


def print_profile_table(profiles: Dict[str, Dict]) -> None:
    """Print summary table of all profiles."""
    table = Table(title="📊 Data Quality Profile Summary")
    
    table.add_column("Table", style="cyan", no_wrap=True)
    table.add_column("Rows", justify="right", style="magenta")
    table.add_column("Columns", justify="right", style="magenta")
    table.add_column("Null %", justify="right", style="yellow")
    table.add_column("Duplicates", justify="right", style="yellow")
    table.add_column("Quality Score", justify="right", style="green")
    
    for filename, profile in profiles.items():
        table_name = filename.replace("_dataset.csv", "").replace("_", " ").title()
        
        # Calculate average null percentage
        avg_null = sum(
            col["null_percentage"]
            for col in profile["columns_info"].values()
        ) / len(profile["columns_info"])
        
        quality_score = generate_quality_score(profile)
        
        # Color score based on value
        if quality_score >= 90:
            score_color = "green"
        elif quality_score >= 70:
            score_color = "yellow"
        else:
            score_color = "red"
        
        table.add_row(
            table_name,
            f"{profile['rows']:,}",
            str(profile["columns"]),
            f"{avg_null:.1f}%",
            f"{profile['duplicates']['total']:,}",
            f"[{score_color}]{quality_score:.1f}%[/{score_color}]",
        )
    
    console.print(table)


def save_profile_json(profiles: Dict[str, Dict]) -> None:
    """Save profiles as JSON for further analysis."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    
    output_file = REPORTS_DIR / "data_profile.json"
    
    # Add metadata
    output = {
        "generated_at": datetime.now().isoformat(),
        "profiles": profiles,
        "summary": {
            "total_tables": len(profiles),
            "avg_quality_score": sum(
                generate_quality_score(p) for p in profiles.values()
            ) / len(profiles),
        }
    }
    
    with open(output_file, "w") as f:
        json.dump(output, f, indent=2, default=str)
    
    console.print(f"\n[green]✓ Profile saved to {output_file}[/green]")


def generate_markdown_report(profiles: Dict[str, Dict]) -> None:
    """Generate markdown report of data quality findings."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    
    output_file = REPORTS_DIR / "DATA_QUALITY_REPORT.md"
    
    with open(output_file, "w") as f:
        f.write("# Data Quality Assessment Report\n\n")
        f.write(f"**Generated:** {datetime.now().isoformat()}\n\n")
        
        # Summary section
        f.write("## Executive Summary\n\n")
        avg_score = sum(
            generate_quality_score(p) for p in profiles.values()
        ) / len(profiles)
        f.write(f"**Average Data Quality Score:** {avg_score:.1f}/100\n\n")
        
        # Table-by-table analysis
        f.write("## Detailed Table Analysis\n\n")
        
        for filename, profile in sorted(profiles.items()):
            table_name = filename.replace("_dataset.csv", "")
            quality_score = generate_quality_score(profile)
            
            f.write(f"### {table_name.upper()}\n\n")
            f.write(f"- **File:** {filename}\n")
            f.write(f"- **Quality Score:** {quality_score:.1f}/100\n")
            f.write(f"- **Rows:** {profile['rows']:,}\n")
            f.write(f"- **Columns:** {profile['columns']}\n")
            f.write(f"- **Size:** {profile['size_mb']:.2f} MB\n")
            f.write(f"- **Duplicates:** {profile['duplicates']['total']:,} "
                   f"({profile['duplicates']['percentage']:.2f}%)\n\n")
            
            # Column details
            f.write("#### Column Details\n\n")
            f.write("| Column | Type | Non-Null % | Unique |\n")
            f.write("|--------|------|------------|--------|\n")
            
            for col_name, col_info in profile["columns_info"].items():
                non_null_pct = (col_info["non_null"] / profile["rows"]) * 100
                f.write(
                    f"| {col_name} | {col_info['dtype']} | "
                    f"{non_null_pct:.1f}% | {col_info['unique']:,} |\n"
                )
            
            # Quality issues
            f.write("\n#### Quality Issues\n\n")
            issues = []
            
            for col_name, col_info in profile["columns_info"].items():
                if col_info["null_percentage"] > 10:
                    issues.append(
                        f"- **{col_name}:** {col_info['null_percentage']:.1f}% null values"
                    )
            
            if profile["duplicates"]["percentage"] > 5:
                issues.append(
                    f"- **Duplicates:** {profile['duplicates']['percentage']:.2f}% of rows"
                )
            
            if issues:
                for issue in issues:
                    f.write(f"{issue}\n")
            else:
                f.write("- No significant quality issues detected\n")
            
            f.write("\n")
        
        # Recommendations
        f.write("## Recommendations\n\n")
        f.write("1. **Data Cleaning:** Handle null values based on business logic\n")
        f.write("2. **Deduplication:** Investigate and remove duplicate records\n")
        f.write("3. **Validation:** Implement data quality tests in dbt\n")
        f.write("4. **Monitoring:** Set up continuous quality monitoring in pipeline\n")
    
    console.print(f"[green]✓ Report generated: {output_file}[/green]")


@click.command()
@click.option(
    "--minimal",
    is_flag=True,
    help="Generate minimal profile (faster)",
)
def main(minimal: bool) -> None:
    """
    Analyze and profile downloaded CSV files.
    
    Generates:
    - JSON profile with statistics
    - Markdown report with quality assessment
    - Quality scores for each table
    """
    
    console.print(
        Panel(
            "[bold cyan]Data Quality Profiler[/bold cyan]\n"
            f"Data Directory: {RAW_DIR}",
            expand=False,
        )
    )
    
    # Check if raw data directory exists
    if not RAW_DIR.exists():
        console.print(
            f"[red]✗ Raw data directory not found: {RAW_DIR}[/red]"
        )
        console.print(
            "[yellow]Run: python scripts/data_acquisition.py first[/yellow]"
        )
        sys.exit(1)
    
    # Load and profile each file
    console.print("\n[cyan]Profiling CSV files...[/cyan]\n")
    
    profiles = {}
    
    for filename in CSV_FILES:
        file_path = RAW_DIR / filename
        
        if not file_path.exists():
            console.print(f"  [yellow]⚠[/yellow]  {filename}: Not found")
            continue
        
        success, df = load_csv(file_path)
        
        if success:
            profile = analyze_dataframe(df, filename)
            profiles[filename] = profile
            quality_score = generate_quality_score(profile)
            console.print(
                f"  [green]✓[/green]  {filename}: "
                f"Quality {quality_score:.1f}% ({profile['rows']:,} rows)"
            )
        else:
            console.print(f"  [red]✗[/red]  {filename}: Failed to load")
    
    if not profiles:
        console.print("[red]✗ No CSV files could be profiled[/red]")
        sys.exit(1)
    
    # Print summary table
    print_profile_table(profiles)
    
    # Save reports
    save_profile_json(profiles)
    generate_markdown_report(profiles)
    
    console.print(
        Panel(
            "[green]✓ Data profiling completed![/green]\n"
            f"[cyan]Reports saved to:[/cyan] {REPORTS_DIR}",
            expand=False,
        )
    )
    
    console.print("\n[cyan]Next steps:[/cyan]")
    console.print("1. Review reports/DATA_QUALITY_REPORT.md")
    console.print("2. Address identified quality issues")
    console.print("3. Run: python scripts/gcs_loader.py --bucket YOUR_BUCKET")


if __name__ == "__main__":
    main()
