request = require 'request-promise'
express = require 'express'
gm = require 'gm'
app = express()

app.get '/', (req, res) ->
  request
    url: 'http://jw.whsw.cn/whsw/other/CheckCode.aspx?datetime=az'
    method: 'GET'
    encoding: null
    resolveWithFullResponse: true
  .then (response) ->
    gm(response.body)
    .resize(420, 132, '!')
    .colorspace('GRAY')
    .blackThreshold(90, 130, 0)
    .whiteThreshold(90, 130, 0)
    .toBuffer (err, buffer) ->
      throw err if err
      res.header 'Set-Cookie', response.headers['set-cookie']
      res.header 'Content-Type', response.headers['content-type']
      res.send buffer
  .catch ->
    res.sendStatus 500

app.listen 8080, ->
  console.log 'app is running ...'
