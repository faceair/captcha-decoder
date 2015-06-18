request = require 'request-promise'
express = require 'express'
Jpeg = require 'jpeg-js'
ImageJS = require 'imagejs'
gm = require 'gm'
app = express()

app.get '/', (req, res) ->
  request
    url: 'http://jw.whsw.cn/whsw/other/CheckCode.aspx?datetime=az'
    method: 'GET'
    encoding: null
    resolveWithFullResponse: true
  .then (response) ->
    res.header 'Set-Cookie', response.headers['set-cookie']
    res.header 'Content-Type', response.headers['content-type']

    stream = gm(response.body)
    .resize(420, 132, '!')
    .colorspace('GRAY')
    .blackThreshold(90, 130, 0)
    .whiteThreshold(90, 130, 0)
    .stream()

    bitmap = new ImageJS.Bitmap()
    bitmap.read stream, type: ImageJS.ImageType.JPG
    .then ->
      for x in [0...420]
        for y in [0...132]
          {r, g, b} = bitmap.getPixel x, y
          if r > 90 and g > 130
            bitmap.setPixel x, y, {r: 255, g: 255, b: 255}
          else
            bitmap.setPixel x, y, {r: 0, g: 0, b: 0}

      buffer = Jpeg.encode(bitmap._data, 90).data
      res.send buffer

  .catch (err) ->
    console.error err.stack
    res.sendStatus 500

app.listen 8080, ->
  console.log 'app is running ...'
