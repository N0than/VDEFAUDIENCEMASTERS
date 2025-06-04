// Simulated data storage (in a real app, this would be in a database)
let shows = [
    {
        id: 1,
        title: "Master Chef",
        channel: "TF1",
        airDate: "2024-02-28T20:50:00",
        genre: "Divertissement",
        description: "Concours de cuisine amateur",
        image: "https://images.unsplash.com/photo-1556910103-1c02745aae4d?ixlib=rb-1.2.1&auto=format&fit=crop&w=2850&q=80",
        actualAudience: null
    },
    {
        id: 2,
        title: "Le 20H",
        channel: "France 2",
        airDate: "2024-02-28T20:00:00",
        genre: "Information",
        description: "Journal télévisé",
        image: "https://images.unsplash.com/photo-1495020689067-958852a7765e?ixlib=rb-1.2.1&auto=format&fit=crop&w=2850&q=80",
        actualAudience: null
    }
];

let predictions = [];
let currentUser = null;
let users = [];

// Auth functions
function toggleAuthMode() {
    const isSignUp = document.getElementById('authTitle').textContent === 'Connexion';
    document.getElementById('authTitle').textContent = isSignUp ? 'Inscription' : 'Connexion';
    document.getElementById('nameGroup').style.display = isSignUp ? 'block' : 'none';
    document.getElementById('submitButton').textContent = isSignUp ? 'S\'inscrire' : 'Se connecter';
    document.getElementById('switchButton').textContent = isSignUp ? 'Déjà un compte ? Se connecter' : 'Créer un compte';
}

function handleAuth(event) {
    event.preventDefault();
    const isSignUp = document.getElementById('authTitle').textContent === 'Inscription';
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    
    if (isSignUp) {
        const name = document.getElementById('name').value;
        if (users.find(u => u.email === email)) {
            showError('Cet email est déjà utilisé');
            return;
        }
        const newUser = { id: users.length + 1, name, email, password, isAdmin: false };
        users.push(newUser);
        currentUser = newUser;
    } else {
        const user = users.find(u => u.email === email && u.password === password);
        if (!user) {
            showError('Email ou mot de passe incorrect');
            return;
        }
        currentUser = user;
    }
    
    showMainApp();
}

function showError(message) {
    const errorElement = document.getElementById('errorMessage');
    errorElement.textContent = message;
    setTimeout(() => {
        errorElement.textContent = '';
    }, 3000);
}

function logout() {
    currentUser = null;
    document.getElementById('authContainer').style.display = 'flex';
    document.getElementById('mainApp').style.display = 'none';
}

function showMainApp() {
    document.getElementById('authContainer').style.display = 'none';
    document.getElementById('mainApp').style.display = 'block';
    loadShows();
    updateAdminVisibility();
}

// Navigation
function showSection(sectionId) {
    document.querySelectorAll('.section').forEach(section => {
        section.classList.remove('active');
    });
    document.getElementById(sectionId).classList.add('active');
    
    document.querySelectorAll('nav button').forEach(button => {
        button.classList.remove('active');
    });
    event.target.classList.add('active');
}

// Shows management
function loadShows() {
    const showsList = document.getElementById('showsList');
    showsList.innerHTML = '';
    
    shows.forEach(show => {
        const prediction = predictions.find(p => p.showId === show.id && p.userId === currentUser?.id);
        const showElement = document.createElement('div');
        showElement.className = 'show-card';
        showElement.innerHTML = `
            <img src="${show.image}" alt="${show.title}">
            <div class="show-card-content">
                <h3>${show.title}</h3>
                <p>${show.channel} - ${show.genre}</p>
                <p>${new Date(show.airDate).toLocaleString()}</p>
                <p>${show.description}</p>
                ${show.actualAudience !== null ? 
                    `<div class="actual-audience">Audience réelle: ${formatAudience(show.actualAudience)}</div>` : ''}
                <div class="prediction-input">
                    <div class="audience-gauge">
                        <input type="range" 
                               min="0" 
                               max="10000000" 
                               step="100000" 
                               class="gauge-slider"
                               oninput="updateGaugeValue(this, ${show.id})"
                               onchange="updatePredictionValue(${show.id}, this.value)"
                               ${prediction?.validated ? 'disabled' : ''}
                               value="${prediction?.audience || 0}">
                        <div class="gauge-value">${formatAudience(prediction?.audience || 0)}</div>
                        <div class="gauge-ticks">
                            <span>0</span>
                            <span>2.5M</span>
                            <span>5M</span>
                            <span>7.5M</span>
                            <span>10M</span>
                        </div>
                    </div>
                    ${!prediction?.validated ? `
                        <button onclick="validatePrediction(${show.id})" class="validate-btn">
                            Valider ma prédiction
                        </button>
                    ` : `
                        <div class="prediction-validated">Prédiction validée</div>
                    `}
                </div>
            </div>
        `;
        showsList.appendChild(showElement);
    });
    
    updateFilters();
}

function formatAudience(value) {
    const number = parseInt(value);
    if (number >= 1000000) {
        return (number / 1000000).toFixed(1) + 'M téléspectateurs';
    } else if (number >= 1000) {
        return (number / 1000).toFixed(0) + 'K téléspectateurs';
    }
    return number.toLocaleString() + ' téléspectateurs';
}

function updateGaugeValue(slider, showId) {
    const value = parseInt(slider.value);
    slider.parentElement.querySelector('.gauge-value').textContent = formatAudience(value);
}

function updatePredictionValue(showId, value) {
    const prediction = predictions.find(
        p => p.userId === currentUser?.id && p.showId === showId
    );
    
    if (prediction && !prediction.validated) {
        prediction.audience = parseInt(value);
    } else if (!prediction) {
        predictions.push({
            id: predictions.length + 1,
            userId: currentUser.id,
            showId: showId,
            audience: parseInt(value),
            timestamp: new Date().toISOString(),
            validated: false
        });
    }
}

function validatePrediction(showId) {
    const prediction = predictions.find(
        p => p.userId === currentUser?.id && p.showId === showId
    );
    
    if (prediction && !prediction.validated) {
        prediction.validated = true;
        prediction.validationTimestamp = new Date().toISOString();
        showSuccess('Prédiction validée avec succès');
        loadShows();
        updatePredictions();
    }
}

function updateFilters() {
    const channels = [...new Set(shows.map(show => show.channel))];
    const genres = [...new Set(shows.map(show => show.genre))];
    
    const channelFilter = document.getElementById('channelFilter');
    const genreFilter = document.getElementById('genreFilter');
    
    channelFilter.innerHTML = '<option value="">Toutes les chaînes</option>' +
        channels.map(channel => `<option value="${channel}">${channel}</option>`).join('');
    
    genreFilter.innerHTML = '<option value="">Tous les genres</option>' +
        genres.map(genre => `<option value="${genre}">${genre}</option>`).join('');
}

function filterShows() {
    const channel = document.getElementById('channelFilter').value;
    const genre = document.getElementById('genreFilter').value;
    
    const filteredShows = shows.filter(show => 
        (!channel || show.channel === channel) &&
        (!genre || show.genre === genre)
    );
    
    const showsList = document.getElementById('showsList');
    showsList.innerHTML = '';
    
    filteredShows.forEach(show => {
        const prediction = predictions.find(p => p.showId === show.id && p.userId === currentUser?.id);
        const showElement = document.createElement('div');
        showElement.className = 'show-card';
        showElement.innerHTML = `
            <img src="${show.image}" alt="${show.title}">
            <div class="show-card-content">
                <h3>${show.title}</h3>
                <p>${show.channel} - ${show.genre}</p>
                <p>${new Date(show.airDate).toLocaleString()}</p>
                <p>${show.description}</p>
                ${show.actualAudience !== null ? 
                    `<div class="actual-audience">Audience réelle: ${formatAudience(show.actualAudience)}</div>` : ''}
                <div class="prediction-input">
                    <div class="audience-gauge">
                        <input type="range" 
                               min="0" 
                               max="10000000" 
                               step="100000" 
                               class="gauge-slider"
                               oninput="updateGaugeValue(this, ${show.id})"
                               onchange="updatePredictionValue(${show.id}, this.value)"
                               ${prediction?.validated ? 'disabled' : ''}
                               value="${prediction?.audience || 0}">
                        <div class="gauge-value">${formatAudience(prediction?.audience || 0)}</div>
                        <div class="gauge-ticks">
                            <span>0</span>
                            <span>2.5M</span>
                            <span>5M</span>
                            <span>7.5M</span>
                            <span>10M</span>
                        </div>
                    </div>
                    ${!prediction?.validated ? `
                        <button onclick="validatePrediction(${show.id})" class="validate-btn">
                            Valider ma prédiction
                        </button>
                    ` : `
                        <div class="prediction-validated">Prédiction validée</div>
                    `}
                </div>
            </div>
        `;
        showsList.appendChild(showElement);
    });
}

function updatePredictions() {
    const predictionsList = document.getElementById('predictionsList');
    if (!predictionsList) return;
    
    const userPredictions = predictions.filter(p => p.userId === currentUser.id);
    
    predictionsList.innerHTML = userPredictions.map(prediction => {
        const show = shows.find(s => s.id === prediction.showId);
        return `
            <div class="prediction-card">
                <h3>${show.title}</h3>
                <p>Votre prédiction: ${formatAudience(prediction.audience)}</p>
                <p>Faite le: ${new Date(prediction.timestamp).toLocaleString()}</p>
                ${prediction.validated ? 
                    `<p class="prediction-status">Prédiction validée le ${new Date(prediction.validationTimestamp).toLocaleString()}</p>` : 
                    '<p class="prediction-status pending">Prédiction en attente de validation</p>'}
                ${show.actualAudience !== null ? `
                    <p>Audience réelle: ${formatAudience(show.actualAudience)}</p>
                    <p>Score: ${calculateScore(prediction.audience, show.actualAudience)}</p>
                ` : ''}
            </div>
        `;
    }).join('');
}

// Admin functions
function updateAdminVisibility() {
    const adminButton = document.querySelector('button[onclick="showSection(\'admin\')"]');
    if (adminButton) {
        adminButton.style.display = currentUser?.isAdmin ? 'inline-block' : 'none';
    }
}

function addShow(event) {
    event.preventDefault();
    const form = event.target;
    const newShow = {
        id: shows.length + 1,
        title: form.title.value,
        channel: form.channel.value,
        airDate: form.airDate.value,
        genre: form.genre.value,
        description: form.description.value,
        image: form.image.value,
        actualAudience: null
    };
    
    shows.push(newShow);
    loadShows();
    form.reset();
    showSuccess('Programme ajouté avec succès');
}

function updateActualAudience(showId, audience) {
    const show = shows.find(s => s.id === showId);
    if (show) {
        show.actualAudience = parseInt(audience);
        loadShows();
        updatePredictions();
        showSuccess('Audience mise à jour avec succès');
    }
}

function calculateScore(predicted, actual) {
    if (predicted === actual) return '200 points';
    const diff = Math.abs(predicted - actual);
    if (diff <= 100000) return '100 points';
    if (diff <= 250000) return '75 points';
    if (diff <= 500000) return '50 points';
    if (diff <= 1000000) return '25 points';
    return '0 points';
}

function showSuccess(message) {
    const successElement = document.createElement('div');
    successElement.className = 'success-message';
    successElement.textContent = message;
    document.body.appendChild(successElement);
    setTimeout(() => {
        successElement.remove();
    }, 3000);
}

// Initialize the app
document.addEventListener('DOMContentLoaded', () => {
    // Create admin user if none exists
    if (!users.find(u => u.isAdmin)) {
        users.push({
            id: 0,
            name: 'Admin',
            email: 'admin@example.com',
            password: 'admin',
            isAdmin: true
        });
    }
    
    // Start with the auth form
    document.getElementById('authContainer').style.display = 'flex';
    document.getElementById('mainApp').style.display = 'none';
});