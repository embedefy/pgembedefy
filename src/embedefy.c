// pgembedefy
// For the full copyright and license information, please view the LICENSE.txt file.

#include <postgres.h>
#include <fmgr.h>
#include <utils/builtins.h>
#include <utils/guc.h>
#include "embedefy.h"
#include "api.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

// _PG_init initializes the module.
void _PG_init(void);
// PG_FUNCTION_INFO_V1 defines the function's metadata.
PG_FUNCTION_INFO_V1(embedefy_embeddings);

// Init vars
static char *embeddings_endpoint = NULL;
static char *embedefy_access_token = NULL;

// _PG_init initializes the module.
void _PG_init(void)
{
    DefineCustomStringVariable("embedefy.embeddings_endpoint", "URL for the Embedefy API", NULL, &embeddings_endpoint, "https://api.embedefy.com/v1/embeddings", PGC_USERSET, 0, NULL, NULL, NULL);
    DefineCustomStringVariable("embedefy.access_token", "Access token for the Embedefy API", NULL, &embedefy_access_token, "", PGC_USERSET, 0, NULL, NULL, NULL);
}

// embedefy_embeddings takes a model name and an input string and returns the embeddings.
Datum embedefy_embeddings(PG_FUNCTION_ARGS)
{
    // Init variables
    char *model, *input, *post_data;
    V1APIResponse api_response;
    V1APIResponseBody api_response_body;
    text *final_result;

    model = text_to_cstring(PG_GETARG_TEXT_P(0));
    input = text_to_cstring(PG_GETARG_TEXT_P(1));
    post_data = psprintf("{\"model\": \"%s\", \"inputs\": [\"%s\"]}", model, input);

    // Make the API request
    // See palloc at curl_write_func which is called by make_v1_api_request
    api_response = make_v1_api_request(embeddings_endpoint, post_data, embedefy_access_token);
    pfree(post_data);

    // Check for errors
    if (api_response.error)
    {
        ereport(ERROR, (errmsg("Embedefy request error: %s", api_response.error)));
        if (api_response.error != NULL)
        {
            pfree(api_response.error);
            api_response.error = NULL;
        }
        if (api_response.data != NULL)
        {
            pfree(api_response.data);
            api_response.data = NULL;
        }
        PG_RETURN_NULL();
    }

    // Parse the API response
    api_response_body = parse_v1_api_response(api_response.data);

    if (api_response.data != NULL)
    {
        // Free api_response.data as it's no longer needed
        pfree(api_response.data);
        api_response.data = NULL;
    }

    // Check for errors
    if (api_response_body.error)
    {
        ereport(ERROR,
                (errmsg(api_response_body.message ? "Embedefy API error: %s: %s" : "Embedefy API error: %s",
                        api_response_body.error,
                        api_response_body.message ? api_response_body.message : "")));

        if (api_response_body.error != NULL)
        {
            free(api_response_body.error);
            api_response_body.error = NULL;
        }
        if (api_response_body.message)
        {
            free(api_response_body.message);
            api_response_body.message = NULL;
        }
        PG_RETURN_NULL();
    }
    else
    {
        // It's valid data
        if (api_response_body.data)
        {
            final_result = cstring_to_text(api_response_body.data);
            if (api_response_body.data != NULL)
            {
                free(api_response_body.data);
                api_response_body.data = NULL;
            }
            PG_RETURN_TEXT_P(final_result);
        }
        else
        {
            ereport(ERROR, (errmsg("failed to parse Embedefy API response")));
            PG_RETURN_NULL();
        }
    }

    PG_RETURN_NULL();
}
