freeagent-cli: Access and control Freeagent data from the command line.

This gem supplies a `fa` executable which can create, read, update and delete
data using the Freeagent API.

You need to specify valid Freeagent app credentials. Generate a Freeagent app at
https://dev.freeagent.com/apps. Ensure you set 'http://localhost:*/' as a valid
OAuth redirect URI. Then export your ID and secret as environment variables
FREEAGENT_APP_ID and FREEAGENT_APP_SECRET. On first run, `fa` will authenticate
you via OAuth so watch out for an authentication URI printed to the console.
