# Poultry Analytics Notifier

## Overview
The Poultry Analytics Notifier is designed to automate the collection and reporting of egg production data. It fetches data from an API, processes it to calculate totals and averages, and formats the results for easy sharing via Slack. This project utilizes a Bash script for data processing and a GitHub Actions workflow to schedule the report generation and delivery.

## Dashboard

View the interactive egg production dashboard at [https://ivanemoje.github.io/poultry-analytics-notifier/](https://ivanemoje.github.io/poultry-analytics-notifier/)


## Setup Instructions

1. **Clone the Repository**
   Begin by cloning the repository to your local machine:
   ```
   git clone <repository-url>
   cd eggsreport
   ```

2. **Environment Variables**
   You need to set up the following environment variables:
   - `ONA_API_TOKEN`: This token is required to authenticate requests to the Ona API. You can obtain this token from your Ona account.
   - `SLACK_BOT_TOKEN`: This token is used to authenticate the Slack bot that will send the report.
   - `SLACK_CHANNEL_ID`: The ID of the Slack channel where the report will be sent.

   You can set these variables in your GitHub repository secrets for the GitHub Actions workflow to access them securely.

## Usage Details

### Running the Script Manually
To run the Poultry Analytics Notifier script manually, execute the following command in your terminal:
```
bash ./scripts/egg_report.sh
```
This will fetch the egg collection data, process it, and output the report to the console.

### GitHub Actions Workflow
The project includes a GitHub Actions workflow defined in `.github/workflows/egg_report.yaml`. This workflow is scheduled to run daily at 05:00 and 22:00 UTC. It will execute the egg report script and send the generated report to the specified Slack channel.

To trigger the workflow manually, you can use the "Run workflow" option in the GitHub Actions tab of your repository.

### GitHub Pages

**Live Dashboard!** View our interactive poultry analytics notifier dashboard at [https://ivanemoje.github.io/poultry-analytics-notifier/](https://ivanemoje.github.io/poultry-analytics-notifier/)

Features:
- Daily egg production metrics
- Interactive data visualizations
- Daily, weekly, and monthly trends
- Mobile-responsive design
- Automatic updates from production data

The dashboard updates automatically when new data is pushed to the repository, providing a live view of your poultry analytics.

## Conclusion
The Poultry Analytics Notifier# simplifies the process of tracking and reporting egg production data. By automating data fetching and reporting, it allows users to focus on analysis and decision-making. For any issues or contributions, please refer to the project's GitHub repository.