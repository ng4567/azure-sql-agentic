# Introduction

This repository contains a a template that can be used to engineer an agentic search system with an Azure SQL database. It is designed as a "fill in the blank" exercise to help one learn to build the system manually by providing scripts to install and provision python and cloud dependencies and some boiler plate code to build agents with the [Microsoft Agent Framework](https://learn.microsoft.com/en-us/agent-framework/overview/agent-framework-overview).

For now, use of Windows 11 is required.

# Pre-Setup Requirements

- Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- Install [uv](https://docs.astral.sh/uv/getting-started/installation/) python pacakge manager
- [Azure](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account) Subscription with sufficient credit and permissions to create and deploy LLMs on [Microsoft Foundry](ai.azure.com)
- [Azure SQL](https://azure.microsoft.com/en-us/products/azure-sql/database) instance populated with data
- Working [Git Installation](https://git-scm.com/install/)

Before deploying cloud dependencies run `az login` to select an azure tenant and authenticate to the Azure CLI.

# Setup

## Clone repo

```powershell
git clone https://github.com/ng4567/azure-sql-agentic.git
cd .\azure-sql-agentic\
```

## Deploy Cloud Resources

```powershell
powershell .\deploy.ps1
```

The script will provision an instance of Microsoft Foundry and create a Foundry project and deploy a [GPT-5-mini](https://ai.azure.com/catalog/models/gpt-5-mini) model inside of it. It will save the necessary API credentials inside a `.env` file to easily use them when writing your Python code.

## Install Python Dependencies & Activate Virtual Environment
```powershell
uv venv .venv/
uv sync
.venv\Scripts\activate.ps1
```

The above commands create a virtual python environment with the uv package manager and then install the dependencies into it before finally activating it. 

## SQL DB Credentials

To help you easily populate the `.env` file with your Azure SQL credentials the run the enclosed [`check-db-credentials.ps1`](check-db-credentials.ps1):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\check-db-credentials.ps1 -ResourceGroup rg-foundry-demo
```

# Run Code & Build!

Test that the cloud & python dependencies were properly setup by running the script. You will know you've succeeded if you see a gibberish LLM response.

```powershell
uv run main.py
```

The python scripts includes some boilerplate code to create two agents, one to generate SQL queries and another one to analyze the results of the SQL queries using the Code Interpretor tool [(link)](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/code-interpreter?view=foundry-classic&tabs=python). Orchestrating the agents to work together and chaining their outputs is left as an exercise for the reader.

You will also need to add your Azure SQL database credentials to the .env file as explained above and write code to extend your agent's functionalities by querying the SQL database. One approach could be to write a function that takes the SQL generator agent's generated SQL queries and uses the Azure SQL DB Python SDK to run the queries.

# Useful Documentation

- Microsoft Agent Framework: [link](https://learn.microsoft.com/en-us/agent-framework/tutorials/agents/run-agent?pivots=programming-language-python)
- Azure SQL Python SDK: [link](https://learn.microsoft.com/en-us/python/api/overview/azure/sql?view=azure-python)