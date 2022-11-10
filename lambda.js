const { DynamoDB } = require('aws-sdk')
var ddb = new DynamoDB({region: process.env.DDB_REGION});

async function handler(event){
    console.log(JSON.stringify(event))
    const method = event.requestContext.http.method
    const id = event.queryStringParameters.id || '350KB'

    if (event.rawPath == '/favicon.ico'){
        return 'free-nova-scotia'
    }

    if(method === 'POST'){
        const s = 'qwertyuiopasdfghjklzxcvbnm1234567890'
        const data = Array.apply(null, Array(parseInt(id*1000))).map(function() { return s.charAt(Math.floor(Math.random() * s.length)); }).join('');

        const res = await ddb.putItem({
            TableName:'CrossRegionLatency',
            Item: {
                ID:{
                    S:id
                },
                DATA : {
                    S:data
                }
            }
        }).promise()
        
        
        return 'ok'
    }else {
        const res = await ddb.getItem({
            TableName:'CrossRegionLatency',
            Key: {
                ID:{
                    S:id
                }
            }
        }).promise()
        
        
        return JSON.stringify(res.Item)
    }
    
}

module.exports = {handler}