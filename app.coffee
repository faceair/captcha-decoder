request = require 'request-promise'
Promise = require 'bluebird'
tesseract = require 'node-tesseract'
tmpdir = require('os').tmpdir()
express = require 'express'
ImageJS = require 'imagejs'
jpeg = require 'jpeg-js'
uuid = require 'node-uuid'
path = require 'path'
_ = require 'lodash'
fs = require 'fs'
gm = require 'gm'
app = express()

app.get '/', (req, res) ->
  request
    url: 'http://jw.whsw.cn/whsw/other/CheckCode.aspx?datetime=az'
    method: 'GET'
    encoding: null
    resolveWithFullResponse: true
  .then (response) ->
    stream = gm(response.body)
    .rotate('white', -13)
    .resize(420, 132, '!')
    .colorspace('GRAY')
    .blackThreshold(90, 130, 0)
    .whiteThreshold(90, 130, 0)
    .stream()

    bitmap = new ImageJS.Bitmap()
    bitmap.read stream, type: ImageJS.ImageType.JPG
    .then ->
      # 二值化
      for y in [0...132]
        for x in [0...420]
          {r, g, b} = bitmap.getPixel x, y
          if r > 90 and g > 130
            bitmap.setPixel x, y, {r: 255, g: 255, b: 255}
          else
            bitmap.setPixel x, y, {r: 0, g: 0, b: 0}

      # 去污点
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

      # X轴上像素分布
      x_line_obj = {}
      x_line_obj[x] = 0 for x in [0...420]

      for y in [0...132]
        for x in [0...420]
          {r, g, b} = bitmap.getPixel x, y
          if r is 0 and g is 0 and b is 0
            x_line_obj[x] += 1

      x_line = _.values x_line_obj

      divide_x = []

      start = 0
      for points, index in x_line
        start = index
        break if points isnt 0

      end = 419
      for points, index in x_line.reverse()
        end = x_line.length - index
        break if points isnt 0
      x_line.reverse()

      render_x_obj = {}

      divide_x_arr = _.filter [start...end], (index) ->
        return _.every [1...40], (near_index) ->
          not_out_start = (index - near_index) > start
          not_out_end = (index + near_index) < end

          less_after = x_line[index] <= x_line[index + near_index]
          less_before = x_line[index] <= x_line[index - near_index]

          return not_out_start and not_out_end and less_after and less_before

      divide_x_arr = divide_x_arr.sort((a, b) -> a - b)

      divide_x_arr_clean = []

      for index in [0...divide_x_arr.length]
        unless divide_x_arr[index]
          continue
        divide_x = divide_x_arr[index]
        for near_index in [1...(divide_x_arr.length - index)]
          unless near_index is (divide_x_arr[index + near_index] - divide_x)
            break
        divide_x_arr_clean.push Math.floor((divide_x_arr[index] + divide_x_arr[index + near_index - 1]) / 2)
        for i in [0...near_index]
          divide_x_arr[index + i] = undefined

      if divide_x_arr_clean.length isnt 3
        divide_x_arr_clean_obj = divide_x_arr_clean.map (index) ->
          return {
            index: index
            points: x_line[index]
          }
        divide_x_arr_clean = _.pluck _.slice(_.sortBy(divide_x_arr_clean_obj, 'points'), 0, 3), 'index'

      divide_x_arr_clean = _.union([start, end], divide_x_arr_clean).sort((a, b) -> a - b)

      divide = []
      square = [
        [divide_x_arr_clean[0], divide_x_arr_clean[1]]
        [divide_x_arr_clean[1], divide_x_arr_clean[2]]
        [divide_x_arr_clean[2], divide_x_arr_clean[3]]
        [divide_x_arr_clean[3], divide_x_arr_clean[4]]
      ]

      for [divide_x_a, divide_x_b] in square
        divide_y = []
        for x in [divide_x_a...divide_x_b + 1]
          for y in [0...132]
            {r, g, b} = bitmap.getPixel x, y
            if r is 0 and g is 0 and b is 0
              divide_y.push y

        min_y = _.min divide_y
        max_y = _.max divide_y

        divide.push [divide_x_a, divide_x_b, min_y, max_y]

      divide_image = divide.map ([divide_x_a, divide_x_b, divide_y_a, divide_y_b]) ->
        return bitmap.crop
          top: divide_y_a
          left: divide_x_a
          width: divide_x_b - divide_x_a
          height: divide_y_b - divide_y_a

      Promise.map divide_image, (char_bitmap) ->
        filepath = "./captchas/captchas-#{uuid.v4()}.jpeg"
        char_bitmap.resize
          width: 120
          height: 120
          algorithm: 'nearestNeighbor'
        .writeFile filepath, type: ImageJS.ImageType.JPG
        .then ->
          Promise.promisify(tesseract.process) filepath,
            l: 'eng'
            psm: 10
            config: 'nobatch captcha'
        .then (char) ->
          char = char.replace /\W+/g, ''
          save = (char, number = 0) ->
            try
              fs.accessSync "./captchas/#{char}-#{number}.jpeg", fs.R_OK
              save char, number + 1
            catch e
              fs.renameSync filepath, "./captchas/#{char}-#{number}.jpeg"
          save char
          return char
      .then (chars) ->
        res.json
          session: response.headers['set-cookie']
          captchas: chars.join ''

  .catch (err) ->
    console.error err.stack
    res.sendStatus 500

app.listen 8080, ->
  console.log 'app is running ...'
