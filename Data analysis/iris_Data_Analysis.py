# Import required libraries
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.datasets import load_iris

#Task 1: Load the Iris dataset

# Load the Iris dataset
try:
    iris = load_iris(as_frame=True)
    df = iris.frame
    print('Dataset loaded successfully.')
except Exception as e:
    print(f'Error loading dataset: {e}')

# Display the first few rows
df.head()

# Check data types and missing values
df.info()
df.isnull().sum()

# Clean the dataset (fill or drop missing values)
if df.isnull().values.any():
    df = df.dropna()
    print('Missing values dropped.')
else:
    print('No missing values found.')


#Task 2: Basic Data Analysis

# Basic statistics of numerical columns
df.describe()

# Group by species and compute mean of numerical columns
df.groupby('target').mean()


#Task 3: Data Visualization

# Line chart: Petal length over samples
plt.figure(figsize=(10, 5))
plt.plot(df.index, df['petal length (cm)'], label='Petal Length (cm)')
plt.title('Petal Length Over Samples')
plt.xlabel('Sample Index')
plt.ylabel('Petal Length (cm)')
plt.legend()
plt.show()


# Bar chart: Average petal length per species
species_names = iris.target_names
avg_petal_length = df.groupby('target')['petal length (cm)'].mean()
plt.figure(figsize=(8, 5))
sns.barplot(x=species_names, y=avg_petal_length.values)
plt.title('Average Petal Length per Species')
plt.xlabel('Species')
plt.ylabel('Average Petal Length (cm)')
plt.show()

# Histogram: Sepal width distribution
plt.figure(figsize=(8, 5))
sns.histplot(df['sepal width (cm)'], bins=20, kde=True)
plt.title('Distribution of Sepal Width')
plt.xlabel('Sepal Width (cm)')
plt.ylabel('Frequency')
plt.show()


# Scatter plot: Sepal length vs Petal length
plt.figure(figsize=(8, 5))
sns.scatterplot(x='sepal length (cm)', y='petal length (cm)', hue='target', data=df, palette='Set1', legend='full')
plt.title('Sepal Length vs Petal Length by Species')
plt.xlabel('Sepal Length (cm)')
plt.ylabel('Petal Length (cm)')
plt.legend(title='Species', labels=species_names)
plt.show()






