const fs = require('fs');

const readJSON = (path) => {
    return new Promise((resolve,reject) => {
        fs.readFile(path,'utf8', (err, data1) => {
              if (err) 
              { 
                  reject(err); 
                  return;
              }  ;
              resolve(data1);
        });
    });
}

const writeToJSON = (saveFileAtPath,dataFile) => {
    let dataArrayJSON = JSON.stringify(dataFile);
    fs.writeFile(saveFileAtPath, dataArrayJSON, (err) => {
        console.log(`crudJSON=>writeToJSON-> Success Write JSON at path: ${saveFileAtPath}`);
    });
}

const appendToTXT = (saveFileAtPath,message) => {
    let log = `${message}`;
    fs.appendFile(saveFileAtPath,log + '\n',(err) => {
       if (err) { console.log(`crudJSON=>appendToTXT->Can not append to ${saveFileAtPath}  error: `,err); }
    });
}



module.exports = {
                    readJSON,
                    writeToJSON,
                    appendToTXT,
                 }