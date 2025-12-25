# dbt Project: Brazilian E-Commerce Data Warehouse

> Data transformation layer for Olist dataset using dbt, BigQuery, and modern analytics engineering practices.

## 📊 Project Structure

```
dbt_project/
├── models/
│   ├── staging/              # Bronze layer - raw data cleaned
│   │   └── stg_*.sql         # Staging models (views)
│   ├── intermediate/         # Silver layer - business logic
│   │   └── int_*.sql         # Intermediate models (tables)
│   ├── marts/                # Gold layer - analytics-ready
│   │   ├── fct_*.sql         # Fact tables
│   │   └── dim_*.sql         # Dimension tables
│   └── sources.yml           # Source definitions
├── tests/                    # Custom dbt tests
├── macros/                   # Reusable SQL logic
├── seeds/                    # Static reference data
├── dbt_project.yml          # Project configuration
└── README.md                # This file
```

## 🚀 Quick Start

### Commands

```bash
# Test connection
dbt debug

# Run all models
dbt run

# Run specific model
dbt run --select stg_orders

# Run all tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve
```

## 🏗️ Data Layers

### Staging (Bronze) Layer
Raw data cleaned and standardized from GCS sources.

### Intermediate (Silver) Layer
Business logic transformations with data enrichment.

### Marts (Gold) Layer
Analytics-ready fact and dimension tables (star schema).

## ✅ Testing

```bash
dbt test
```

Includes:
- Unique constraints
- Not null validations
- Referential integrity
- Accepted values

## 📚 Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [BigQuery Reference](https://cloud.google.com/bigquery/docs)
- [Jinja Templating](https://jinja.palletsprojects.com/)
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
