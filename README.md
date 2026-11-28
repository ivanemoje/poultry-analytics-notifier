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
   - `EXPENSES_ONA_FORM_ID` optionally overrides the expenses form ID, which defaults to `856758`.
   - `SLACK_BOT_TOKEN`: This token is used to authenticate the Slack bot that will send the report.
   - `SLACK_CHANNEL_ID`: The ID of the Slack channel where the report will be sent.

   You can set these variables in your GitHub repository secrets for the GitHub Actions workflow to access them securely.

## Usage Details

### Running the Script Manually
To run the Poultry Analytics Notifier script manually, execute the following command in your terminal:
```
bash ./scripts/poultry_analytics.sh
```
This fetches production, sales, and expenses from Ona, writes `poultry_analytics_data.json` and `poultry_sales_data.json` under the Git-ignored `.local/analytics/` directory, and prints the combined Slack summary. Set `POULTRY_DATA_DIR` to use another output directory.

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

Production periods end on the latest recorded survey date. Financial periods end on the latest recorded transaction date.

The Financial tab shows sales and expenses from their respective Ona forms. The selected period applies to the financial totals, charts, records, and average tray price. The average tray price uses regular tray sales with a recorded quantity. The 7-, 30-, and 90-day rolling sales totals are measured through the latest recorded sale date. Pig expenses appear in Expense Records and are excluded from poultry expenses and poultry net income.

The dashboard shows laying batches by default. **Include inactive batches** reveals other batches and their historical records. The production view shows trays, loose eggs, and broken eggs separately. The Batches tab also shows recorded deaths and daily feed in grams per bird.

The Overview and Production cards show the laying percentage for the selected period and batch. For each submission with a tray or loose egg count, the calculation includes those eggs and the configured current bird count for that laying batch. The percentage divides the resulting egg total by the sum of those bird counts across reporting submissions. Historical rates also use the current counts in `config/batch_metadata.json`.

Record newly observed deaths in the batch's death field on the daily Ona production form, using the survey date when they were counted. Enter zero when the batch was checked and no birds died. Correct an existing submission in Ona if its count was wrong. The next scheduled sync imports the entries automatically. On the Batches tab, choose a period to see its recorded deaths or choose **All** for the full history. Current Birds comes from the configured headcount. Automatically adjusting it would require a verified count and count date for each batch so that only subsequent deaths are deducted.

## Conclusion
The Poultry notifier project simplifies the process of tracking and reporting egg production data. By automating data fetching and reporting, it allows users to focus on analysis and decision-making. For any issues or contributions, please refer to the project's GitHub repository.
