curl  \
 --request PUT \
 --digest --user admin:admin \
 --upload-file ./triple-explorer.xqy \
 --header "Content-type: application/xquery" \
 "http://localhost:8005/v1/config/resources/tripleExplorer?version=1.0&provider=Matthew Royal&description=a graph visualization web interface for MarkLogic triple stores&method=get&get:arg1=xs:string*"

