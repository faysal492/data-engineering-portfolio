#!/usr/bin/env python3
"""
Kaggle Data Acquisition Script
==============================
Downloads the Brazilian E-Commerce (Olist) dataset from Kaggle.

This script:
1. Authenticates with Kaggle API using credentials
2. Downloads the complete Olist dataset (~100k orders)
3. Extracts CSV files to data/raw/
4. Validates downloaded data
5. Generates summary statistics

Requirements:
    - Kaggle account and API credentials (~/.kaggle/kaggle.json)
    - Dependencies: kaggle, pandas, click, rich

Usage:
    python scripts/data_acquisition.py                  # Download everything
    python scripts/data_acquisition.py --validate       # Download + validate
    python scripts/data_acquisition.py --test           # Test API connection only
"""

import os
import sys
import zipfile
import json
from pathlib import Path
from typing import Dict, List, Tuple
from datetime import datetime

import pandas as pd
import click
from rich.console import Console
from rich.table import Table
from rich.progress import Progress
from rich.panel import Panel

# Initialize Rich console for pretty output
console = Console()

# Configuration
KAGGLE_DATASET = "olist/brazilian-ecommerce"
DATA_DIR = Path(__file__).parent.parent / "data"
RAW_DIR = DATA_DIR / "raw"
TEMP_DIR = DATA_DIR / ".temp_download"

# Expected CSV files in the dataset
EXPECTED_FILES = {
    "olist_orders_dataset.csv": "Orders",
    "olist_order_items_dataset.csv": "Order Items",
    "olist_customers_dataset.csv": "Customers",
    "olist_sellers_dataset.csv": "Sellers",
    "olist_products_dataset.csv": "Products",
    "olist_order_payments_dataset.csv": "Payments",
    "olist_order_reviews_dataset.csv": "Reviews",
    "olist_geolocation_dataset.csv": "Geolocation",
    "product_category_name_translation.csv": "Category Translation",
}


def check_kaggle_credentials() -> bool:
    """Check if Kaggle API credentials are configured."""
    kaggle_dir = Path.home() / ".kaggle"
    kaggle_json = kaggle_dir / "kaggle.json"
    
    if not kaggle_json.exists():
        console.print(
            f"[red]✗ Kaggle credentials not found at {kaggle_json}[/red]"
        )
        console.print(
            "\n[yellow]📋 Setup Instructions:[/yellow]"
        )
        console.print(
            "1. Create Kaggle account: https://www.kaggle.com/register"
        )
        console.print("2. Go to Account Settings → API → Create New API Token")
        console.print(f"3. Place kaggle.json in: {kaggle_dir}")
        console.print("4. Run: chmod 600 ~/.kaggle/kaggle.json")
        return False
    
    # Verify credentials are valid JSON
    try:
        with open(kaggle_json) as f:
            creds = json.load(f)
        if "username" not in creds or "key" not in creds:
            console.print("[red]✗ kaggle.json is missing username or key[/red]")
            return False
    except json.JSONDecodeError:
        console.print("[red]✗ kaggle.json is not valid JSON[/red]")
        return False
    
    console.print(f"[green]✓ Kaggle credentials found[/green]")
    return True


def test_kaggle_connection() -> bool:
    """Test connection to Kaggle API."""
    try:
        from kaggle.api.kaggle_api_extended import KaggleApi
        
        api = KaggleApi()
        api.authenticate()
        console.print("[green]✓ Successfully authenticated with Kaggle API[/green]")
        return True
    except Exception as e:
        console.print(f"[red]✗ Kaggle authentication failed: {e}[/red]")
        return False


def prepare_directories() -> None:
    """Create necessary directories."""
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    console.print(f"[green]✓ Directories prepared[/green]")


def download_dataset() -> bool:
    """Download dataset from Kaggle."""
    try:
        from kaggle.api.kaggle_api_extended import KaggleApi
        
        api = KaggleApi()
        api.authenticate()
        
        console.print(f"\n[cyan]Downloading {KAGGLE_DATASET}...[/cyan]")
        
        # Download to temp directory
        api.dataset_download_files(KAGGLE_DATASET, path=TEMP_DIR, unzip=True)
        
        console.print(f"[green]✓ Dataset downloaded successfully[/green]")
        return True
        
    except Exception as e:
        console.print(f"[red]✗ Download failed: {e}[/red]")
        return False


def verify_downloaded_files() -> Tuple[bool, List[str], List[str]]:
    """Verify all expected files were downloaded."""
    downloaded = []
    missing = []
    
    for filename in EXPECTED_FILES.keys():
        filepath = TEMP_DIR / filename
        if filepath.exists():
            downloaded.append(filename)
        else:
            missing.append(filename)
    
    return len(missing) == 0, downloaded, missing


def move_to_raw_dir(files: List[str]) -> None:
    """Move downloaded files to raw data directory."""
    for filename in files:
        src = TEMP_DIR / filename
        dst = RAW_DIR / filename
        
        if src.exists():
            src.rename(dst)
    
    # Clean up temp directory
    if TEMP_DIR.exists():
        TEMP_DIR.rmdir()
    
    console.print(f"[green]✓ Files moved to {RAW_DIR}[/green]")


def load_and_validate_data() -> Dict[str, Dict]:
    """Load and validate downloaded data."""
    stats = {}
    
    console.print("\n[cyan]Validating downloaded data...[/cyan]")
    
    for filename, display_name in EXPECTED_FILES.items():
        filepath = RAW_DIR / filename
        
        if not filepath.exists():
            stats[display_name] = {"status": "missing", "rows": 0, "columns": 0}
            continue
        
        try:
            df = pd.read_csv(filepath)
            stats[display_name] = {
                "status": "ok",
                "rows": len(df),
                "columns": len(df.columns),
                "size_mb": filepath.stat().st_size / (1024 * 1024),
            }
        except Exception as e:
            stats[display_name] = {"status": "error", "error": str(e)}
    
    return stats


def print_summary(stats: Dict) -> None:
    """Print summary statistics table."""
    table = Table(title="📊 Downloaded Dataset Summary")
    
    table.add_column("Table", style="cyan", no_wrap=True)
    table.add_column("Status", style="green")
    table.add_column("Rows", justify="right", style="magenta")
    table.add_column("Columns", justify="right", style="magenta")
    table.add_column("Size (MB)", justify="right", style="magenta")
    
    total_rows = 0
    total_size = 0
    
    for table_name, info in stats.items():
        if info["status"] == "ok":
            table.add_row(
                table_name,
                "✓",
                f"{info['rows']:,}",
                str(info["columns"]),
                f"{info['size_mb']:.2f}",
            )
            total_rows += info["rows"]
            total_size += info["size_mb"]
        elif info["status"] == "missing":
            table.add_row(table_name, "✗ Missing", "-", "-", "-")
        else:
            table.add_row(table_name, "✗ Error", "-", "-", "-")
    
    console.print(table)
    
    console.print(f"\n[bold]Total Statistics:[/bold]")
    console.print(f"  • Total Rows: {total_rows:,}")
    console.print(f"  • Total Size: {total_size:.2f} MB")
    console.print(f"  • Timestamp: {datetime.now().isoformat()}")


def create_metadata_file(stats: Dict) -> None:
    """Create metadata file with download information."""
    metadata = {
        "dataset": KAGGLE_DATASET,
        "downloaded_at": datetime.now().isoformat(),
        "tables": {
            name: {
                "rows": stat.get("rows", 0),
                "columns": stat.get("columns", 0),
                "size_mb": stat.get("size_mb", 0),
            }
            for name, stat in stats.items()
            if stat["status"] == "ok"
        }
    }
    
    metadata_file = RAW_DIR / "_metadata.json"
    with open(metadata_file, "w") as f:
        json.dump(metadata, f, indent=2)
    
    console.print(f"\n[green]✓ Metadata saved to {metadata_file}[/green]")


@click.command()
@click.option(
    "--validate",
    is_flag=True,
    help="Validate downloaded data after download",
)
@click.option(
    "--test",
    is_flag=True,
    help="Test Kaggle API connection only (don't download)",
)
@click.option(
    "--force",
    is_flag=True,
    help="Force re-download even if files exist",
)
def main(validate: bool, test: bool, force: bool) -> None:
    """
    Download Brazilian E-Commerce dataset from Kaggle.
    
    This script downloads all CSV files from the Olist dataset including:
    - Orders, customers, sellers, products
    - Payments, reviews, order items
    - Geolocation, product category translations
    """
    
    console.print(
        Panel(
            "[bold cyan]Brazilian E-Commerce Data Acquisition[/bold cyan]\n"
            f"Dataset: {KAGGLE_DATASET}",
            expand=False,
        )
    )
    
    # Check credentials
    if not check_kaggle_credentials():
        sys.exit(1)
    
    # Test connection if requested
    if test:
        console.print("\n[cyan]Testing Kaggle API connection...[/cyan]")
        if test_kaggle_connection():
            console.print("[green]✓ Connection successful![/green]")
        else:
            sys.exit(1)
        return
    
    # Check if data already exists
    existing_files = list(RAW_DIR.glob("*.csv"))
    if existing_files and not force:
        console.print(
            f"\n[yellow]⚠️  Found {len(existing_files)} CSV files in {RAW_DIR}[/yellow]"
        )
        console.print(
            "[yellow]Use --force flag to re-download[/yellow]"
        )
        
        if validate:
            console.print("\n[cyan]Validating existing data...[/cyan]")
            stats = load_and_validate_data()
            print_summary(stats)
        return
    
    # Prepare directories
    prepare_directories()
    
    # Download dataset
    if not download_dataset():
        sys.exit(1)
    
    # Verify downloads
    success, downloaded, missing = verify_downloaded_files()
    
    if missing:
        console.print(f"\n[yellow]⚠️  Missing files: {missing}[/yellow]")
    
    # Move files
    if downloaded:
        move_to_raw_dir(downloaded)
    
    # Validate if requested
    if validate or True:  # Always validate
        stats = load_and_validate_data()
        print_summary(stats)
        create_metadata_file(stats)
    
    if success:
        console.print(
            Panel(
                "[green]✓ Dataset acquisition completed successfully![/green]",
                expand=False,
            )
        )
        console.print("\n[cyan]Next steps:[/cyan]")
        console.print("1. Run: python scripts/data_profiler.py")
        console.print("2. Run: python scripts/gcs_loader.py")
        console.print("3. Check: data/raw/_metadata.json for summary")
    else:
        console.print(
            Panel(
                "[red]✗ Some files are missing. Check output above.[/red]",
                expand=False,
            )
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
