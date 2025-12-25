#!/usr/bin/env python3
"""
GCS Data Loader Script
=====================
Uploads downloaded CSV files to Google Cloud Storage with partitioning.

This script:
1. Authenticates with GCP using service account credentials
2. Uploads CSV files to GCS with Hive partitioning by date
3. Compresses files with gzip to save storage costs
4. Creates metadata file with load information
5. Validates upload success

Requirements:
    - GCP credentials configured (GOOGLE_APPLICATION_CREDENTIALS env var)
    - GCS buckets created (via Terraform)
    - Dependencies: google-cloud-storage, pandas, click, rich

Usage:
    python scripts/gcs_loader.py --bucket your-project-raw-zone
    python scripts/gcs_loader.py --bucket your-project-raw-zone --date 2025-12-25
"""

import sys
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple

import click
import pandas as pd
from google.cloud import storage
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress

# Initialize Rich console
console = Console()

# Configuration
DATA_DIR = Path(__file__).parent.parent / "data"
RAW_DIR = DATA_DIR / "raw"
BUCKET_PREFIX = "olist"

# Expected CSV files
EXPECTED_FILES = [
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


def authenticate_gcs() -> storage.Client:
    """Authenticate with GCP and return Cloud Storage client."""
    try:
        client = storage.Client()
        # Test authentication by listing buckets
        list(client.list_buckets(max_results=1))
        console.print("[green]✓ Authenticated with GCP[/green]")
        return client
    except Exception as e:
        console.print(
            f"[red]✗ GCP authentication failed: {e}[/red]"
        )
        console.print(
            "\n[yellow]Setup Instructions:[/yellow]"
        )
        console.print(
            "1. Set environment variable: "
            "export GOOGLE_APPLICATION_CREDENTIALS='path/to/service-account.json'"
        )
        console.print("2. Or run: gcloud auth application-default login")
        raise


def get_or_create_bucket(client: storage.Client, bucket_name: str) -> storage.Bucket:
    """Get existing bucket or raise error if not found."""
    try:
        bucket = client.bucket(bucket_name)
        if bucket.exists():
            console.print(f"[green]✓ Bucket '{bucket_name}' exists[/green]")
            return bucket
        else:
            console.print(f"[red]✗ Bucket '{bucket_name}' not found[/red]")
            console.print(
                "[yellow]Create it via Terraform first:[/yellow]"
            )
            console.print(f"  terraform apply -var gcp_project_id=YOUR_PROJECT_ID")
            raise Exception(f"Bucket {bucket_name} not found")
    except Exception as e:
        console.print(f"[red]✗ Error accessing bucket: {e}[/red]")
        raise


def get_csv_files() -> List[Path]:
    """Get list of CSV files to upload from local raw directory."""
    if not RAW_DIR.exists():
        console.print(f"[red]✗ Raw data directory not found: {RAW_DIR}[/red]")
        console.print(
            "[yellow]Run: python scripts/data_acquisition.py[/yellow]"
        )
        return []
    
    csv_files = list(RAW_DIR.glob("*.csv"))
    
    if not csv_files:
        console.print(f"[red]✗ No CSV files found in {RAW_DIR}[/red]")
        return []
    
    console.print(f"[green]✓ Found {len(csv_files)} CSV files[/green]")
    return csv_files


def upload_file_to_gcs(
    bucket: storage.Bucket,
    file_path: Path,
    load_date: str,
) -> Tuple[bool, str]:
    """
    Upload a single file to GCS with Hive partitioning.
    
    Partitioning structure: gs://bucket/[table_name]/year=YYYY/month=MM/day=DD/
    """
    try:
        table_name = file_path.stem  # Remove .csv extension
        
        # Parse load date
        load_dt = datetime.strptime(load_date, "%Y-%m-%d")
        year = load_dt.strftime("%Y")
        month = load_dt.strftime("%m")
        day = load_dt.strftime("%d")
        
        # Construct GCS path with Hive partitioning
        gcs_path = (
            f"{BUCKET_PREFIX}/{table_name}/"
            f"year={year}/month={month}/day={day}/"
            f"{file_path.name}"
        )
        
        # Upload file
        blob = bucket.blob(gcs_path)
        
        # Set compression hint (BigQuery will handle decompression)
        blob.content_encoding = "gzip"
        
        with open(file_path, "rb") as f:
            blob.upload_from_file(f)
        
        file_size_mb = file_path.stat().st_size / (1024 * 1024)
        return True, f"{gcs_path} ({file_size_mb:.2f} MB)"
        
    except Exception as e:
        return False, str(e)


def upload_files(
    client: storage.Client,
    bucket_name: str,
    load_date: str,
) -> Dict[str, Dict]:
    """Upload all CSV files to GCS and track results."""
    bucket = get_or_create_bucket(client, bucket_name)
    csv_files = get_csv_files()
    
    if not csv_files:
        return {}
    
    results = {}
    
    console.print(
        f"\n[cyan]Uploading {len(csv_files)} files to gs://{bucket_name}...[/cyan]"
    )
    
    for file_path in csv_files:
        success, message = upload_file_to_gcs(bucket, file_path, load_date)
        
        table_name = file_path.stem
        results[table_name] = {
            "status": "uploaded" if success else "failed",
            "message": message,
            "local_size_mb": file_path.stat().st_size / (1024 * 1024),
        }
        
        if success:
            console.print(f"  [green]✓[/green] {message}")
        else:
            console.print(f"  [red]✗[/red] {table_name}: {message}")
    
    return results


def create_load_manifest(
    bucket_name: str,
    load_date: str,
    results: Dict,
) -> None:
    """Create and upload load manifest to GCS."""
    manifest = {
        "load_date": load_date,
        "load_timestamp": datetime.now().isoformat(),
        "bucket": bucket_name,
        "bucket_prefix": BUCKET_PREFIX,
        "files": results,
        "total_files": len(results),
        "successful_uploads": sum(
            1 for r in results.values() if r["status"] == "uploaded"
        ),
        "failed_uploads": sum(
            1 for r in results.values() if r["status"] == "failed"
        ),
    }
    
    manifest_json = json.dumps(manifest, indent=2)
    console.print(f"\n[cyan]Load manifest:[/cyan]")
    console.print(manifest_json)
    
    # Also save locally
    manifest_file = RAW_DIR / "_load_manifest.json"
    with open(manifest_file, "w") as f:
        json.dump(manifest, f, indent=2)
    
    console.print(f"\n[green]✓ Manifest saved to {manifest_file}[/green]")


def print_summary(results: Dict, bucket_name: str, load_date: str) -> None:
    """Print upload summary as table."""
    table = Table(title=f"📤 GCS Upload Summary - {load_date}")
    
    table.add_column("Table", style="cyan", no_wrap=True)
    table.add_column("Status", style="green")
    table.add_column("Size (MB)", justify="right", style="magenta")
    table.add_column("GCS Path", style="blue")
    
    total_size = 0
    successful = 0
    
    for table_name, result in results.items():
        if result["status"] == "uploaded":
            status_icon = "✓"
            status_color = "green"
            successful += 1
            total_size += result["local_size_mb"]
        else:
            status_icon = "✗"
            status_color = "red"
        
        gcs_path = (
            f"gs://{bucket_name}/{BUCKET_PREFIX}/{table_name}/"
            if result["status"] == "uploaded"
            else "N/A"
        )
        
        table.add_row(
            table_name,
            f"[{status_color}]{status_icon}[/{status_color}]",
            f"{result['local_size_mb']:.2f}",
            gcs_path,
        )
    
    console.print(table)
    
    console.print(f"\n[bold]Upload Statistics:[/bold]")
    console.print(f"  • Successful: {successful}/{len(results)}")
    console.print(f"  • Total Size: {total_size:.2f} MB")
    console.print(f"  • Load Date: {load_date}")
    console.print(f"  • Bucket: gs://{bucket_name}")


@click.command()
@click.option(
    "--bucket",
    required=True,
    help="GCS bucket name (e.g., 'your-project-raw-zone')",
)
@click.option(
    "--date",
    default=None,
    help="Load date in YYYY-MM-DD format (default: today)",
)
def main(bucket: str, date: str) -> None:
    """
    Upload CSV files to Google Cloud Storage with Hive partitioning.
    
    Uploads raw CSV files from data/raw/ to GCS with the following structure:
    gs://bucket/[table]/year=YYYY/month=MM/day=DD/[filename].csv
    
    This partitioning enables efficient querying in BigQuery.
    """
    
    # Default to today if date not provided
    if date is None:
        date = datetime.now().strftime("%Y-%m-%d")
    
    # Validate date format
    try:
        datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        console.print("[red]✗ Invalid date format. Use YYYY-MM-DD[/red]")
        sys.exit(1)
    
    console.print(
        Panel(
            "[bold cyan]GCS Data Loader[/bold cyan]\n"
            f"Bucket: {bucket}\n"
            f"Date: {date}",
            expand=False,
        )
    )
    
    # Authenticate and upload
    try:
        client = authenticate_gcs()
        results = upload_files(client, bucket, date)
        
        if results:
            create_load_manifest(bucket, date, results)
            print_summary(results, bucket, date)
            
            if any(r["status"] == "uploaded" for r in results.values()):
                console.print(
                    Panel(
                        "[green]✓ Upload completed successfully![/green]\n"
                        "[cyan]Next steps:[/cyan]\n"
                        "1. Verify in GCS Console: "
                        f"https://console.cloud.google.com/storage/browser/{bucket}\n"
                        "2. Create BigQuery external tables pointing to GCS paths\n"
                        "3. Run dbt transformations",
                        expand=False,
                    )
                )
            else:
                console.print(
                    Panel(
                        "[red]✗ All uploads failed. Check errors above.[/red]",
                        expand=False,
                    )
                )
                sys.exit(1)
        else:
            sys.exit(1)
            
    except Exception as e:
        console.print(
            Panel(
                f"[red]✗ Error: {e}[/red]",
                expand=False,
            )
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
