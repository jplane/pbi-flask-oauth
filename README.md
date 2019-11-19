## Sample: AAD-protected Flask API + Power BI Desktop custom connector

The Flask app is configured for OAuth with [Flask-Dance](https://flask-dance.readthedocs.io/en/latest/providers.html#module-flask_dance.contrib.azure).

The Power BI custom connector is configured to use [OAuth2 (v2) authorization_code flow](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow).

### Setup:

* Register an application in Azure AD and obtain the app_id, secret, and tenant_id. You'll also need to configure a redirect URL value of https://oauth.powerbi.com/views/oauthredirect.html

* Add your app_id to [pbi-connector/client_id](pbi-connector/client_id) as the only contents of that file

* In [pbi-connector/MyGraph.pq](pbi-connector/MyGraph.pq) replace TENANT-ID with your tenant_id from Azure AD app registration

* Modify [flask-oauth-azure/.env](flask-oauth-azure/.env) with your app_id, secret, and tenant_id

* You'll need Visual Studio + [Power Query SDK](https://marketplace.visualstudio.com/items?itemName=Dakahn.PowerQuerySDK) to build the pbi-connector project

* The Flask app runs in Docker... you can run it directly on your laptop, but whyyy

### From your shell:

* Run [build.sh](build.sh) to build the Docker image

* Run [run.sh](run.sh) to run the image, the server is visible at http://localhost:5000. Use the /data secure endpoint to retrieve data

* Build the pbi-connector project in Visual Studio and use F5 debugging to test it within VS