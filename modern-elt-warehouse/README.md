# 🇧🇷 Modern ELT Warehouse: Brazilian E-Commerce Intelligence Platform

[![Pipeline Status](https://github.com/faysal492/data-engineering-portfolio/actions/workflows/elt-pipeline.yml/badge.svg)](https://github.com/faysal492/data-engineering-portfolio/actions)
[![dbt](https://img.shields.io/badge/dbt-1.7+-orange?logo=dbt)](https://www.getdbt.com/)
[![BigQuery](https://img.shields.io/badge/BigQuery-Free%20Tier-blue?logo=google-cloud)](https://cloud.google.com/bigquery)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> A production-ready ELT pipeline processing **100,000+ real Brazilian e-commerce transactions** into an analytics-optimized data warehouse using modern data stack best practices.

---

## 📊 Business Value Proposition

This platform transforms raw Olist marketplace data into actionable business intelligence:

| Metric | Business Impact |
|--------|----------------|
| 🎯 **Customer Lifetime Value** | Identify high-value customer segments |
| 📦 **Order Fulfillment** | Optimize delivery times and reduce delays |
| ⭐ **Seller Performance** | Rank and monitor seller quality metrics |
| 💳 **Payment Success Rate** | Track payment method performance |
| 🗺️ **Geographic Analysis** | Understand regional sales patterns |

---

## 🏗️ Technical Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DATA PIPELINE ARCHITECTURE                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │     │              │
│   KAGGLE     │────▶│   PYTHON     │────▶│    GCS       │────▶│  BIGQUERY    │
│   (Olist)    │     │   ETL        │     │  Raw Zone    │     │  Bronze      │
│              │     │              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                                                                      │
                                                                      ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │     │              │
│   LOOKER     │◀────│  BIGQUERY    │◀────│    dbt       │◀────│  BIGQUERY    │
│   STUDIO     │     │  Gold Layer  │     │  Transform   │     │  Silver      │
│              │     │              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
        │                   │                    │                    │
        └───────────────────┴────────────────────┴────────────────────┘
                                      │
                              ┌───────┴───────┐
                              │   GITHUB      │
                              │   ACTIONS     │
                              │   (CI/CD)     │
                              └───────────────┘
```

### Data Flow Layers

| Layer | Description | Technology |
|-------|-------------|------------|
| **Extract** | Download Olist dataset from Kaggle | Python + Kaggle API |
| **Load (Raw)** | Store raw CSVs with partitioning | Google Cloud Storage |
| **Bronze** | Raw tables in BigQuery | BigQuery External Tables |
| **Silver** | Cleaned, validated data | dbt Intermediate Models |
| **Gold** | Star schema for analytics | dbt Mart Models |
| **Serve** | Business dashboards | Looker Studio |

---

## 📁 Project Structure

```
modern-elt-warehouse/
├── 📂 scripts/
│   ├── data_acquisition.py      # Kaggle API integration
│   ├── gcs_loader.py            # Partitioned upload to GCS
│   └── data_profiler.py         # Data quality assessment
│
├── 📂 dbt_project/
│   ├── models/
│   │   ├── staging/             # Bronze layer (stg_*)
│   │   ├── intermediate/        # Silver layer (int_*)
│   │   └── marts/               # Gold layer (dim_*, fct_*)
│   ├── tests/                   # Custom data tests
│   ├── macros/                  # Reusable SQL logic
│   ├── seeds/                   # Static reference data
│   └── docs/                    # Data documentation
│
├── 📂 great_expectations/
│   ├── expectations/            # Data validation suites
│   └── checkpoints/             # Validation checkpoints
│
├── 📂 .github/workflows/
│   └── elt-pipeline.yml         # CI/CD automation
│
├── 📂 terraform/                # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── 📂 data/                     # Local data (gitignored)
│   ├── raw/                     # Downloaded CSVs
│   └── processed/               # Transformed outputs
│
├── 📂 docs/                     # Project documentation
│   ├── data_dictionary.md
│   └── runbook.md
│
├── requirements.txt             # Python dependencies
├── profiles.yml                 # dbt connection profiles
└── README.md                    # This file
```

---

## 🚀 Quick Start

### Prerequisites

- Python 3.9+
- Google Cloud SDK
- Kaggle account with API credentials

### 1. Clone & Setup Environment

```bash
# Clone the repository
git clone https://github.com/faysal492/data-engineering-portfolio.git
cd data-engineering-portfolio/modern-elt-warehouse

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Credentials

```bash
# Set up Kaggle credentials
mkdir -p ~/.kaggle
cp kaggle.json ~/.kaggle/
chmod 600 ~/.kaggle/kaggle.json

# Set up GCP credentials
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
```

### 3. Run the Pipeline

```bash
# Download data from Kaggle
python scripts/data_acquisition.py

# Upload to GCS
python scripts/gcs_loader.py

# Run dbt transformations
cd dbt_project
dbt deps
dbt run
dbt test
```

---

## 📊 Data Model

### Star Schema (Gold Layer)

```
                          ┌─────────────────┐
                          │   fct_orders    │
                          │─────────────────│
                          │ order_id (PK)   │
                          │ customer_key    │──────┐
                          │ seller_key      │──────┼──┐
                          │ product_key     │──────┼──┼──┐
                          │ date_key        │──────┼──┼──┼──┐
                          │ order_status    │      │  │  │  │
                          │ payment_value   │      │  │  │  │
                          │ freight_value   │      │  │  │  │
                          │ review_score    │      │  │  │  │
                          └─────────────────┘      │  │  │  │
                                                   │  │  │  │
┌─────────────────┐  ┌─────────────────┐  ┌───────┴──┴──┴──┴───────┐
│  dim_customers  │  │   dim_sellers   │  │      dim_products      │
│─────────────────│  │─────────────────│  │────────────────────────│
│ customer_key    │  │ seller_key      │  │ product_key            │
│ customer_id     │  │ seller_id       │  │ product_id             │
│ customer_city   │  │ seller_city     │  │ product_category       │
│ customer_state  │  │ seller_state    │  │ product_weight_g       │
│ customer_zip    │  │ seller_zip      │  │ product_length_cm      │
└─────────────────┘  └─────────────────┘  └────────────────────────┘

                     ┌─────────────────┐
                     │    dim_date     │
                     │─────────────────│
                     │ date_key        │
                     │ full_date       │
                     │ year            │
                     │ month           │
                     │ day_of_week     │
                     │ is_weekend      │
                     └─────────────────┘
```

### Source Tables (Olist Dataset)

| Table | Rows | Description |
|-------|------|-------------|
| `orders` | 99,441 | Order header information |
| `order_items` | 112,650 | Order line items |
| `customers` | 99,441 | Customer demographics |
| `sellers` | 3,095 | Seller information |
| `products` | 32,951 | Product catalog |
| `payments` | 103,886 | Payment transactions |
| `reviews` | 99,224 | Customer reviews |
| `geolocation` | 1,000,163 | Zip code coordinates |

---

## 🎯 Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| ⏱️ Pipeline Runtime | < 30 min | ✅ |
| ✅ Data Quality Score | > 95% | ✅ |
| 💰 Monthly GCP Cost | $0 | ✅ |
| 🔄 Automation | Daily runs | ✅ |
| 📚 Documentation | Complete | ✅ |

---

## 🛠️ Technology Stack

| Category | Technology |
|----------|------------|
| **Language** | Python 3.11, SQL |
| **Transformation** | dbt-core 1.7+ |
| **Data Warehouse** | Google BigQuery |
| **Object Storage** | Google Cloud Storage |
| **Data Quality** | dbt tests, Great Expectations |
| **Orchestration** | GitHub Actions |
| **IaC** | Terraform |
| **Visualization** | Looker Studio |

---

## 📈 Key Insights Generated

1. **Customer Segmentation**: RFM analysis identifying VIP customers
2. **Delivery Performance**: Average delivery time by region
3. **Seller Rankings**: Top performers by revenue and ratings
4. **Payment Analysis**: Success rates by payment method
5. **Product Categories**: Best-selling categories by state

---

## 🔧 Development

### Running Tests

```bash
# dbt tests
cd dbt_project
dbt test

# Great Expectations validation
great_expectations checkpoint run olist_checkpoint
```

### Generating Documentation

```bash
cd dbt_project
dbt docs generate
dbt docs serve
```

---

## 📝 Lessons Learned

1. **Brazilian Timezone Handling**: Converted all timestamps from BRT (UTC-3) to UTC
2. **Currency Considerations**: Values are in BRL, added USD conversion rates
3. **Missing Geolocation**: Imputed ~5% missing coordinates using city averages
4. **Review Delays**: Handled reviews submitted months after delivery

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Faysal**
- GitHub: [@faysal492](https://github.com/faysal492)

---

<p align="center">
  <i>Built with ❤️ for the data engineering community</i>
</p>
