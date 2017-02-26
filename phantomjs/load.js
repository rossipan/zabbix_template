"use strict";
var page = require('webpage').create(),
    system = require('system'),
    resourceRequested = 0,
    resourceReceivedError = 0,
    t, address;

page.settings.userAgent = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36';

if (system.args.length === 1) {
    console.log('Usage: netlog.js <some URL>');
    phantom.exit(1);
} else {
    t = Date.now();
    address = system.args[1];

    page.onResourceRequested = function (requestData, request) {
        if (/ssl.google-analytics\.com\//.test(requestData.url)) {
            console.log('The url of the request is matching. Aborting: ' + requestData['url']);
            request.abort();
        } else {
            resourceRequested++;
//          console.log('Requested: ' + JSON.stringify(requestData, undefined, 4));
//          console.log('Requested: #' + requestData.id + ', "method":"' + requestData.method + '", "url":"' + requestData.url + '", "status":"' + requestData.status + '", "redirectURL":"' + requestData.redirectURL + '", "contentType":"' + requestData.contentType  + '"');
        }
    };

    page.onResourceReceived = function (res) {
        if (res.stage === "end" && res.status >= 400) {
            resourceReceivedError++;
            console.log('received: ' + JSON.stringify(res, undefined, 4));
//          console.log('Response: #' + res.id + ', "stage":"' + res.stage + '", "url":"' + res.url + '", "status":"' + res.status + '", "redirectURL":"' + res.redirectURL + '", "contentType":"' + res.contentType  + '"');
        }
    };

    page.open(address, function (status) {
        if (status !== 'success') {
            console.log('#FAIL to load the address');
        }

        t = Date.now() - t;
        console.log('#Loading time:' + t);
        console.log('#ResourceRequested:' + resourceRequested);
        console.log('#ResourceError    :' + resourceReceivedError);
        phantom.exit();
    });

    page.onError = function(msg, trace) {
        var msgStack = ['ERROR: ' + msg];
        if (trace && trace.length) {
            msgStack.push('TRACE:');
            trace.forEach(function(t) {
              msgStack.push(' -> ' + t.file + ': ' + t.line + (t.function ? ' (in function "' + t.function +'")' : ''));
            });
        }
          console.error(msgStack.join('\n'));
          console.error('#JavaScriptExecution:True');
    };
}