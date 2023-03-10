<!-- homeAstroportStation function API Twist -->
async function homeAstroportStation() {
  try {

     let one = await fetch('/?qrcode=station'); // Gets a promise
     var doc =  await one.text();
     var regex = /url='([^']+)/i; // Get response PORT
     var redirectURL = doc.match(regex)[1]

     console.log(redirectURL)
     document.getElementById("ainfo").innerHTML = "Teleportation ... (3s) " + redirectURL;

    setTimeout(function() {
            // let two = await fetch(redirectURL);
            // document.mydiv.innerHTML = await two.text(); // Replaces body with response
            window.location.href = redirectURL
            // window.open( redirectURL, "AstroTab");
    }, 3000);

  } catch (err) {
    console.log('Fetch error:' + err); // Error handling
  }
}

function promptUser(g1pub) {
    let salt = prompt("Identifiant");
    let pepper = prompt("Code Secret");
    let resultText = `/?salt=${salt}&pepper=${pepper}&star=1&friend=${g1pub}`;
    console.log(resultText)
    document.getElementById("debug").innerHTML = resultText;
}
