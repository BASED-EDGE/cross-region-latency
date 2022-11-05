const { DynamoDB } = require('aws-sdk')
var ddb = new DynamoDB({region: process.env.DDB_REGION});

async function handler(){
    const res = await ddb.getItem({
        TableName:'CrossRegionLatency',
        Key: {
            ID:{
                S:'350KB'
            }
        }
    }).promise()
    
    
    return JSON.stringify(res.Item)
}

module.exports = {handler}