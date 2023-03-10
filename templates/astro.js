<!-- homeAstroportStation function API Twist -->
async function homeAstroportStation() {
  try {

     let one = await fetch('http://127.0.0.1:1234/?qrcode=station'); // Gets a promise
     var doc =  await one.text();
     var regex = /url='([^']+)/i; // Get response PORT
     var redirectURL = doc.match(regex)[1]

     console.log(redirectURL)

    setTimeout(function() {
            // let two = await fetch(redirectURL);
            // document.mydiv.innerHTML = await two.text(); // Replaces body with response
            window.location.href = redirectURL
            // window.open( redirectURL, "AstroTab");
    }, 15000);

  } catch (err) {
    console.log('Fetch error:' + err); // Error handling
  }
}
