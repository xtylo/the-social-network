// Defines the API routes for content management and recommendations.

const express = require('express');
const router = express.Router();
const { getRecommendations } = require('../controllers/recommendationController');

// Route to get content recommendations
router.get('/recommendations/:userId', async (req, res) => {
    try {
        const recommendations = await getRecommendations(req.params.userId);
        res.json(recommendations);
    } catch (error) {
        res.status(500).json({ error: 'Failed to get recommendations' });
    }
});

module.exports = router;
