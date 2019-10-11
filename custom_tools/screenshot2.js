#!/usr/bin/env node
 
const log = require('why-is-node-running')
const genericPool = require('generic-pool');
const puppeteer = require('puppeteer');
const fs = require('fs');
const util = require('util');
 
process.setMaxListeners(0);
 
var browser = null;

const factory = {
  create: async function() {
    const page = await browser.newPage();
    await page.setViewport({ width: 800, height: 420 });
    return page;
  },
  destroy: async function(page) {
    await page.goto('about:blank');
    await page.close();
    return;
  },
};
 
const browserPagePool = genericPool.createPool(factory, {
  max: 20,
  min: 0,
  idleTimeoutMillis: 1500
});
 
//module.exports = browserPagePool;
 
 
process.argv.shift();
process.argv.shift();
 
if (process.argv.length < 2) {
  console.log("Usage: screenshot2 outfile.txt domain1 domain2 ip3 domain4 etc \n*** NO http:// or port, just a raw domain or ip. it will screenshot likely services.")
  process.exit();
}
 
const outfile = process.argv.shift();
 
const targets = process.argv;
const schemes = ['http', 'https'];
const ports = ["80", "443", "3000", "8080"];
 
var target_list = [];
var outfile_list = [];
var dumb_outlines = [];
 
targets.forEach(function(target) {
  ports.forEach(function(port) {
    var scheme = "";
    if (port == "443") {
      scheme = "https";
    } else if (port == "80") {
      scheme = "http";
    } else {
      scheme = "http"
    }
    var full_target =  scheme+"://"+target+":"+port+"/";
    //output_ss_file_name = "../../public/ss/"+scheme+target+port+"-ss.png";
    var output_ss_file_name = scheme+target+port+"-ss.png";
    var outline = scheme + " " + target + " " + port;
 
 
    target_list.push(full_target);
    outfile_list.push(output_ss_file_name);
    dumb_outlines.push(outline);
  });
});
 
async function take_ss(url, filepath, outline) {
  const page = await browserPagePool.acquire();
 
  try {
 
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36');
 
    await console.log("testing: " + url);
     
    const resp = await page.goto(url, {waitUntil: 'load', timeout: 2000});
    const statusCode = await resp.status();
 
    await console.log("resp: ", statusCode);
     
    if(statusCode == "200" || statusCode == "400" || statusCode == "500" || statusCode == "404" || statusCode == "503") {
      console.log("exists, screenshotting: " + url);
 
      await page.screenshot({path: "../../public/ss/"+filepath,
        clip:  {
          x: 0,
          y: 0,
          width: 1280, 
          height: 720
      }});
 
      //await page.screenshot({path: "../../public/ss/"+filepath.replace("ss.png", "ss-small.png"),
      //  clip:  {
      //    x: 0,
      //    y: 0,
      //    width: 1280, 
      //    height: 720
      //}});
  
      await fs.writeFile("web-applications-"+Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15) + ".txt", outline, 'ascii', function() {});
    } else {
      await console.log("not interesting: " + url + " " + resp.status());
    }
 
  } catch (e) {
    await page.close();
    // page didn't load or timed out
  } finally {
    await browserPagePool.destroy(page); // not releasing?
  }
  //await page.goto("about:blank", {waitUntil: 'load', timeout: 2500});
}
 
////
 
 
function perform_ss() {
  for(var i = 0; i < target_list.length; i++) {
    take_ss(target_list[i], outfile_list[i], dumb_outlines[i] );
  }
}

async function main() {
  browser = await puppeteer.launch({
    // dumpio: true,
    // headless: false,
    // executablePath: 'google-chrome',
    args: ['--no-sandbox', '--disable-setuid-sandbox'], // , '--disable-dev-shm-usage']
    //headless: true,
    ignoreHTTPSErrors: true
  });
  perform_ss();
  const checker = setInterval(async () => {
    if (browserPagePool.size === 0) {
      await browserPagePool.drain();
      browserPagePool.clear();
      browser.close();
      clearInterval(checker);
    }
  }, 500);
}

main();

