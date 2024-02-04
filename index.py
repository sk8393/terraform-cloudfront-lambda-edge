import json

def lambda_handler(event, context):
    print("event = {}".format(event))
    request = event['Records'][0]['cf']['request']
    uri = request['uri']
    print("uri = {}".format(uri))
    headers = request['headers']
    print("headers = {}".format(headers))
    viewer_country = headers.get('cloudfront-viewer-country')
    if viewer_country:
        country_code = viewer_country[0]['value']
        print("country_code = {}".format(country_code))
        if country_code == 'DE' and uri == '/index.html':
            new_uri = '/de/index.html'
        elif country_code == 'IE' and uri == '/index.html':
            new_uri = '/ie/index.html'
        else:
            # If there was no matching country code, move the request as it was made originally.
            return request
    else:
        # If the URI was different from /index.html, move the request as it was made originally.
        return request

    response = {
        'status': '301',
        'statusDescription': 'Permanent Redirect',
        'headers': {
            'location': [{
                'key': 'Location',
                'value': new_uri
            }]
        }
    }
    return response
