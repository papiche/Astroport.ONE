<!-- homeAstroportStation function API Twist -->

// Include <div id="ainfo"></div> in your HTML
async function ainfo(zURL){
  try {
        let two = await fetch(zURL); // Gets a promise
        var miam =  await two.text();
        console.log(miam)

        document.getElementById("ainfo").innerHTML = two.text(); // Replaces id='ainfo' with response

  } catch (err) {
    console.log('Fetch error:' + err); // Error handling
  }
}

// Include <div id="countdown"></div> in your HTML
async function homeAstroportStation(myURL, option = '', duration = 3000) {
  try {

     let one = await fetch(myURL); // Gets a promise
     var doc =  await one.text();
     var regex = /url='([^']+)/i; // Get response PORT
     var redirectURL = doc.match(regex)[1]

    console.log(option + " ... Teleportation ... in " + duration + " ms ... " + redirectURL)

    // start countdown
    var timeLeft = Math.floor(duration / 1000);
    var elem = document.getElementById("countdown");
    var timerId = setInterval(countdown, 1000);

    function countdown() {
        if (timeLeft == -1) {

            clearTimeout(timerId);
            switch(option) {
                    case "tab":
                          window.open( redirectURL, "AstroTab");
                          break;
                    case "page":
                          window.location.replace(redirectURL);
                          break;
                    case "parent":
                          window.parent.location.href = redirectURL;
                          break;
                    case "aframe":
                          document.getElementById("aframe").src = redirectURL;
                          break;
                    case "ainfo":
                          ainfo(redirectURL);
                          break;
                    default:
                          window.location.href = redirectURL;

              }

              if (document.getElementById("countdown").innerHTML !== '') {
                document.getElementById("countdown").innerHTML = "<a href='"+redirectURL+"' target='aframe'>OK</a>";
              }

        } else {

            elem.innerHTML = timeLeft + " s";
            timeLeft--;

        }
    }


  } catch (err) {
    console.log('Fetch error:' + err + myURL ); // Error handling
  }
}




// <center><div id="countdown"></div></center>

function promptUser(inout) {
    let salt = prompt("Secret 1");
    let pepper = prompt("Secret 2");
    let email = prompt("Email");

    let resultUt = '/?salt=' + salt + '&pepper=' + pepper + '&' + inout + '=' + email;
    console.log(resultUt)
    homeAstroportStation( resultUt,'', 12000)
}

