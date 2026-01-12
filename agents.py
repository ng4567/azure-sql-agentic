import asyncio
from agent_framework.azure import AzureOpenAIChatClient
from azure.identity import AzureCliCredential
from agent_framework import HostedCodeInterpreterTool
from dotenv import load_dotenv
import os
import pyodbc
load_dotenv()

###################################
# Azure SQL DB Connection Setup

# server = os.getenv('SQL_SERVER')  # e.g., 'your_server.database.windows.net'
# database = os.getenv('SQL_DATABASE')  # e.g., 'your_database'
# username = os.getenv('SQL_USERNAME')  # e.g., 'your_username'
# password = os.getenv('SQL_PASSWORD')  # e.g., 'your_password'
# driver= '{ODBC Driver 13 for SQL Server}'

# cnxn = pyodbc.connect('DRIVER=' + driver + ';SERVER=' + server + ';PORT=1433;DATABASE=' + database + ';UID=' + username + ';PWD=' + password)
# cursor = cnxn.cursor()


# Example Query:
# cursor.execute("SELECT TOP 20 pc.Name as CategoryName, p.name as ProductName FROM [SalesLT].[ProductCategory] pc JOIN [SalesLT].[Product] p ON pc.productcategoryid = p.productcategoryid")
# row = cursor.fetchone()
# while row:
#     print (str(row[0]) + " " + str(row[1]))
#     row = cursor.fetchone()
###################################

credential = AzureCliCredential()
user_questions = ["What are the most common problems with respective resolutions?", "Are there any patterns we should focus on correcting?", "Which project has the most issues? What type of issues? Are there any particular patterns of root cause?"]
schema = ""

sql_query_generator_agent = AzureOpenAIChatClient(credential=credential).create_agent(
    instructions=f"You are a helpful agent meant to write SQL queries to query the data necessary for the provided schema: {schema}. The user has the following question: {user_questions[0]}. Write a SQL query to answer the user's question based on the provided schema.",
    name="sql_query_generator_agent"
)

code_interpreter_agent = AzureOpenAIChatClient(credential=credential).create_agent(
    instructions=f"You are a code interpreter agent. You will be provided with the results of a query from a SQL database. Write the code necessary to analyze it and then return the answer to the user's question: {user_questions[0]}",
    name="code_interpreter_agent",
    tools=[HostedCodeInterpreterTool()]
)

async def main():
    result = await code_interpreter_agent.run("Analyze this dataset and create a visualization")
    print(result)

if __name__ == "__main__": 
    asyncio.run(main())

