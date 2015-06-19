request = require 'request-promise'
express = require 'express'
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
      for y in [0...132]
        for x in [0...420]
          {r, g, b} = bitmap.getPixel x, y
          if r > 90 and g > 130
            bitmap.setPixel x, y, {r: 255, g: 255, b: 255}
          else
            bitmap.setPixel x, y, {r: 0, g: 0, b: 0}

      near_point = []
      for i in [-5...5]
        for j in [-5...5]
          near_point.push [i, j]

      for y in [0...132]
        for x in [0...420]
          {r, g, b} = bitmap.getPixel x, y
          if r < 10
            black_point = 0
            for [a, b] in near_point
              if x + a >= 0 and x + a <= 419 and y + b >= 0 and y + b <= 132
                if bitmap.getPixel(x + a, y + b).r < 10
                  black_point += 1

            if black_point < 30
              bitmap.setPixel x, y, {r: 255, g: 255, b: 255}

      bitmap.write res, type: ImageJS.ImageType.JPG
  .catch (err) ->
    console.error err.stack
    res.sendStatus 500

app.listen 8080, ->
  console.log 'app is running ...'
