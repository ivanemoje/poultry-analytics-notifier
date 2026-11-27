# Poultry Analytics Notifier

## Overview
The Poultry Analytics Notifier fetches Ona submissions, generates dashboard data and a Slack report with Python 3, and runs on a GitHub Actions schedule.

## Dashboard

View the interactive egg production dashboard at [https://ivanemoje.github.io/poultry-analytics-notifier/](https://ivanemoje.github.io/poultry-analytics-notifier/)


## Setup Instructions

1. **Clone the Repository**
   Begin by cloning the repository to your local machine:
   ```
   git clone git@github.com:ivanemoje/poultry-analytics-notifier.git
   cd poultry-analytics-notifier
   ```

2. **Environment Variables**
   You need to set up the following environment variables:
   - `ONA_API_TOKEN`: This token is required to authenticate requests to the Ona API. You can obtain this token from your Ona account.
   - `ONA_FORM_ID` identifies the egg production form.
   - `SALES_ONA_FORM_ID` optionally overrides the sales form ID, which defaults to `853534`.
   - `SLACK_BOT_TOKEN`: This token is used to authenticate the Slack bot that will send the report.
   - `SLACK_CHANNEL_ID`: The ID of the Slack channel where the report will be sent.

   You can set these variables in your GitHub repository secrets for the GitHub Actions workflow to access them securely.

## Usage Details

### Running the Script Manually
To run the Poultry Analytics Notifier script manually, execute the following command in your terminal:
```
bash ./scripts/poultry_analytics.sh
```
This fetches both Ona forms, writes `poultry_analytics_data.json` and `poultry_sales_data.json` under the Git-ignored `.local/analytics/` directory, and prints the combined Slack summary. Set `POULTRY_DATA_DIR` to use another output directory.

### GitHub Actions Workflow
The GitHub Actions workflow runs daily at 22:00 UTC. It runs the combined analytics script and sends the report to the configured Slack channel.

To trigger the workflow manually, you can use the "Run workflow" option in the GitHub Actions tab of your repository.

### GitHub Pages

**Live Dashboard!** View our interactive poultry analytics notifier dashboard at [https://ivanemoje.github.io/poultry-analytics-notifier/](https://ivanemoje.github.io/poultry-analytics-notifier/)

Features:
- Daily egg production metrics
- Interactive data visualizations
- Daily, weekly, and monthly trends
- Mobile-responsive design
- Automatic updates from production data

GitHub Actions publishes the generated JSON files to the `dashboard-data` branch. The dashboard reads that branch directly, so scheduled data updates leave `main` free of generated commits. The checked-in analytics JSON serves as a fallback while the branch is unavailable. Local browser previews can also read the Git-ignored output from a server on localhost.

The **1D** period shows the latest recorded survey day for production and the latest recorded transaction day for financial graphs.

The Financial tab shows sales from the Ona sales form. The period filter applies to the sales records table. The average tray price uses regular tray sales with a recorded quantity over the last three weeks of sales data. The dashboard uses the existing expense snapshot when the sales form has no expense entries.

The Batches tab shows all five batches. Batch and period filters apply to the records table, which shows trays, loose eggs, broken eggs, recorded deaths, and daily feed in grams per bird. Egg totals include available records for every batch.

Laying percentages use the current bird counts in `config/batch_metadata.json` for batches marked `active` or `laying` with a reported egg or tray count. This applies to historical percentages as well. The combined rate divides eligible eggs by eligible birds.

## Conclusion
The Poultry notifier project simplifies the process of tracking and reporting egg production data. By automating data fetching and reporting, it allows users to focus on analysis and decision-making. For any issues or contributions, please refer to the project's GitHub repository.
