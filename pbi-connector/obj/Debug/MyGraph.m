﻿section DashConnector;

//
// OAuth configuration settings
//

// TODO: set AAD client ID value in the client_id file
client_id = Json.Document ( Extension.Contents( "appsettings.json") ) [oauth][client_id];
client_secret = Json.Document ( Extension.Contents( "appsettings.json") ) [oauth][client_secret];
tenant = Json.Document ( Extension.Contents( "appsettings.json") ) [oauth][tenant];
redirect_uri = Json.Document ( Extension.Contents( "appsettings.json") ) [oauth][redirect_uri];
token_uri = "https://login.microsoftonline.com/" & tenant & "/oauth2/v2.0/token";
authorize_uri = "https://login.microsoftonline.com/" & tenant & "/oauth2/v2.0/authorize";
logout_uri = "https://login.microsoftonline.com/logout.srf";

windowWidth = 720;
windowHeight = 1024;

// The "offline_access" scope is required to receive a refresh token value. It is added
// separately from the Graph scopes. Please see
// https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent#offline_access
//
// For more information on available Graph scopes, please see 
// https://developer.microsoft.com/en-us/graph/docs/authorization/permission_scopes 
scope_prefix = "https://pyfuncapi.microsoft.onmicrosoft.com/";
scopes = {
    "user_impersonation"
};

//
// Exported function(s)
//
[DataSource.Kind="DashConnector", Publish="DashConnector.UI"]
shared DashConnector.Feed = () =>
    let
//         results = Web.Contents("http://localhost:7071/api/data"),
        results = Web.Contents("https://pyfuncapi.azurewebsites.net/api/data"),
        source = Json.Document(results)
    in
        source;

//
// Data Source definition
//
DashConnector = [
    TestConnection = (dataSourcePath) => { "DashConnector.Feed" },
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
        ]
    ],
    Label = "My Dash Connector"
];

//
// UI Export definition
//
DashConnector.UI = [
    Beta = true,
    ButtonText = { "DashConnector.Feed", "Connect to Dash Feed" },
    SourceImage = DashConnector.Icons,
    SourceTypeImage = DashConnector.Icons
];

DashConnector.Icons = [
    Icon16 = { Extension.Contents("MyGraph16.png"), Extension.Contents("MyGraph20.png"), Extension.Contents("MyGraph24.png"), Extension.Contents("MyGraph32.png") },
    Icon32 = { Extension.Contents("MyGraph32.png"), Extension.Contents("MyGraph40.png"), Extension.Contents("MyGraph48.png"), Extension.Contents("MyGraph64.png") }
];

//
// OAuth implementation
//
// See the following links for more details on AAD/Graph OAuth:
// * https://docs.microsoft.com/en-us/azure/active-directory/active-directory-protocols-oauth-code 
// * https://graph.microsoft.io/en-us/docs/authorization/app_authorization
//
// StartLogin builds a record containing the information needed for the client
// to initiate an OAuth flow. Note for the AAD flow, the display parameter is
// not used.
//
// resourceUrl: Derived from the required arguments to the data source function
//              and is used when the OAuth flow requires a specific resource to 
//              be passed in, or the authorization URL is calculated (i.e. when
//              the tenant name/ID is included in the URL). In this example, we
//              are hardcoding the use of the "common" tenant, as specified by
//              the 'authorize_uri' variable.
// state:       Client state value we pass through to the service.
// display:     Used by certain OAuth services to display information to the
//              user.
//
// Returns a record containing the following fields:
// LoginUri:     The full URI to use to initiate the OAuth flow dialog.
// CallbackUri:  The return_uri value. The client will consider the OAuth
//               flow complete when it receives a redirect to this URI. This
//               generally needs to match the return_uri value that was
//               registered for your application/client. 
// WindowHeight: Suggested OAuth window height (in pixels).
// WindowWidth:  Suggested OAuth window width (in pixels).
// Context:      Optional context value that will be passed in to the FinishLogin
//               function once the redirect_uri is reached. 
//
StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            scope = "openid",
            response_type = "code",
            response_mode = "query",
            login = "login"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

// FinishLogin is called when the OAuth flow reaches the specified redirect_uri. 
// Note for the AAD flow, the context and state parameters are not used. 
//
// context:     The value of the Context field returned by StartLogin. Use this to 
//              pass along information derived during the StartLogin call (such as
//              tenant ID)
// callbackUri: The callbackUri containing the authorization_code from the service.
// state:       State information that was specified during the call to StartLogin. 
FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

// Called when the access_token has expired, and a refresh_token is available.
// 
Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

Logout = (token) => logout_uri;


// grantType:  Maps to the "grant_type" query parameter.
// tokenField: The name of the query parameter to pass in the code.
// code:       Is the actual code (authorization_code or refresh_token) to send to the service.
TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = client_id,
            client_secret = client_secret,
            scope = GetScopeString(scopes, scope_prefix),
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

//
// Helper Functions
//
Value.IfNull = (a, b) => if a <> null then a else b;

GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;
