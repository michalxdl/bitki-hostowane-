window.addEventListener("message", (event) => {
    switch (event.data.type) {
        case "ShowUI":
            $(".players").fadeIn();
            $("#team1").text(event.data.firstteam)
            $("#team2").text(event.data.secondteam)
            break;
        case "Set":
            $(event.data.toSet).text(event.data.players);
            break;
        case "Update":
            $(event.data.toUpdate).text(Number($(event.data.toUpdate).text()) - 1);
            break;
        case "HideUI":
            $(".players").fadeOut();
            break;
    }
});

function showCountdown(team1, team2) {
    const overlay = document.getElementById('overlay');
    const titleElement = document.getElementById('title');
    const teamsElement = document.getElementById('teams');
    const countdownElement = document.getElementById('countdown');

    console.log('showCountdown function called');


    overlay.style.display = 'flex';
    overlay.style.opacity = 1;
    overlay.style.transform = 'translateY(0)';

    titleElement.textContent = 'HOSTED';
    

    teamsElement.innerHTML = `<span class="team1">${team1}</span> VS <span class="team2">${team2}</span>`;
    
    let timeLeft = 3;
    countdownElement.textContent = timeLeft;

    const interval = setInterval(() => {
        timeLeft--;
        if (timeLeft > 0) {
            countdownElement.textContent = timeLeft;
        } else {

            titleElement.textContent = 'JAZDA';
            countdownElement.textContent = 'GO';
        }
        if (timeLeft <= 0) {
            clearInterval(interval);
            setTimeout(() => {

                overlay.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
                overlay.style.opacity = 0;
                overlay.style.transform = 'translateY(-20px)';
                setTimeout(() => {

                    overlay.style.display = 'none';
                }, 500); 
            }, 500); 
        }
    }, 1000);
}




window.addEventListener('message', function (event) {
    console.log('Received message:', event.data);
    if (event.data.type === 'showCountdown') {
        showCountdown(event.data.team1, event.data.team2);
    }
});
